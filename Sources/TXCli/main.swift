//
//  main.swift
//  TXCli
//
//  Created by Stelios Petrakis on 27/11/20.
//  Copyright © 2020 Transifex. All rights reserved.
//

import Transifex
import TXCliLib
import ArgumentParser
import Foundation

/// All possible error codes that might trigger a failure during the execution of a TXCli command.
enum CommandError : Error {
    case missingToken
    case missingSecret
    case exporterInitializationFailure
    case exportingFailure
    case xliffParserInitializationFailure
    case xliffParsingFailure
    case cdsPushFailure
    case cdsPullFailure
    case translationsEncodingFailure
    case outputDirectoryCreationFailure
    case outputFileWritingFailure
    case cdsCacheInvalidationFailure
}

/// Base command of TXCli app, this command describes the basic usage of the CLI app and lists all
/// subcommands.
struct TXCli: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "txios-cli",
        abstract: "Transifex command-line tool for iOS",
        discussion: """
This command-line tool helps developers push the iOS source strings to Transifex
or download existing translations and transform them into ready-to-use assets
that can be bundled with the iOS application.

The tool can be also used to force CDS cache invalidation so that the next pull
command will fetch fresh translations from CDS.
""",
        version: "1.0",
        subcommands: [Push.self, Pull.self, Invalidate.self])
}

/// Shared options between all subcommands of TXCli.
struct Options: ParsableArguments {
    static let TOKEN_ENV = "TRANSIFEX_TOKEN"
    static let SECRET_ENV = "TRANSIFEX_SECRET"
    
    @Option(name: .long, help: "Transifex token")
    var token: String?

    @Option(name: .long, help: "Transifex secret")
    var secret: String?
    
    @Flag(name: .long, help: "Extra logging for debugging purposes")
    var verbose: Bool = false
}

/// The push subcommand of the CLI app is responsible for exporting the base localization from a Xcode
/// project, parsing the generated XLIFF file, generating the CDS-ready structure and pushing that structure
/// to CDS using the provided  credentials.
struct Push: ParsableCommand {
    @OptionGroup var options: Options

    public static let configuration = CommandConfiguration(
        commandName: "push",
        abstract: "Pushes source strings to Transifex.",
        discussion: """
You can either provide the Transifex token and secret via enviroment variables
(TRANSIFEX_TOKEN, TRANSIFEX_SECRET) or via the --token and --secret parameters.
"""
    )
    
    @Option(name: .long, help: "Source locale")
    private var sourceLocale: String = "en"

    @Option(name: .long, help: """
Path to the .xcodeproj file of the project
(e.g. ../MyProject/myproject.xcodeproj)
""")
    private var project : String
    
    @Flag(name: .long, help: """
If purge: true, then replace the entire resource content with the pushed content
of this request.

If purge: false (default), then append the source content of this request to the
existing resource content.
""")
    private var purge: Bool = false
    
    @Flag(name: .long, help: """
Whether to keep the temporary folder that contains the generated .xcloc or not.
""")
    private var keepTempFolder: Bool = false
    
    @Option(name: .long, parsing: .upToNextOption, help: """
A list of optional global tags to be included in all source strings pushed to
the CDS server.
""")
    private var tags: [String] = []
    
    func run() throws {
        let logHandler = CliLogHandler()
        logHandler.verbose = options.verbose
        
        TXLogger.setHandler(handler: logHandler)
        
        guard let transifexToken = options.token ?? ProcessInfo.processInfo.environment[Options.TOKEN_ENV] else {
            logHandler.error("Missing Transifex token")
            throw CommandError.missingToken
        }
        
        logHandler.verbose("[prompt]Using token: \(transifexToken)[end]")
        
        guard let transifexSecret = options.secret ?? ProcessInfo.processInfo.environment[Options.SECRET_ENV] else {
            logHandler.error("Missing Transifex secret")
            throw CommandError.missingSecret
        }
        
        logHandler.verbose("[prompt]Using secret: \(transifexSecret)[end]")
        
        guard let localizationExporter = LocalizationExporter(sourceLocale: sourceLocale,
                                                              project: project,
                                                              logHandler: logHandler) else {
            logHandler.error("Failed to initialize localization exporter")
            throw CommandError.exporterInitializationFailure
        }
        
        defer {
            if !keepTempFolder {
                localizationExporter.cleanup()
            }
        }
        
        guard let xliffURL = localizationExporter.export() else {
            logHandler.error("Localization export failed")
            throw CommandError.exportingFailure
        }
        
        guard let parser = XLIFFParser(fileURL: xliffURL,
                                       logHandler: logHandler) else {
            logHandler.error("Failed to initialize XLIFF parser")
            throw CommandError.xliffParserInitializationFailure
        }
        
        if !parser.parse() {
            logHandler.error("XLIFF parsing failed")
            throw CommandError.xliffParsingFailure
        }
        
        var translations: [TXSourceString] = []
        
        for result in XLIFFParser.consolidate(parser.results) {
            let key = txGenerateKey(sourceString: result.id,
                                    context: nil)
            
            // Get the .target instead of the .source of the result as user
            // might have localized the string for the base locale.
            var sourceString = result.target
            
            // If the result contains string dict elements, convert them to
            // ICU format and use that as a source string
            if let icuRule = result.generateICURuleIfPossible() {
                sourceString = icuRule
            }
            
            let translationUnit = TXSourceString(key: key,
                                                 sourceString: sourceString,
                                                 occurrences: result.files,
                                                 characterLimit: 0,
                                                 developerComment: result.note,
                                                 tags: tags)
            
            // Do not add the same key twice, occurrences is used for that
            guard !translations.contains(translationUnit) else {
                continue
            }
            
            translations.append(translationUnit)
        }

        logHandler.verbose("[high]Initializing TxNative...[end]")
        
        TXNative.initialize(locales: TXLocaleState(sourceLocale: sourceLocale),
                            token: transifexToken,
                            secret: transifexSecret,
                            cache: TXNoOpCache())
        
        logHandler.info("""
[high]Pushing[end] [num]\(translations.count)[end] [high]source strings to CDS ([end][prompt]Purge: \(purge ? "Yes" : "No")[end][high])...[end]
""")
        
        // Block until the push logic completes using a semaphore.
        let semaphore = DispatchSemaphore(value: 0)
        var pushResult = false
        TXNative.pushTranslations(translations,
                                  purge: purge) { (result) in
            pushResult = result
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if !pushResult {
            logHandler.error("Error while pushing source strings to CDS")
            throw CommandError.cdsPushFailure
        }
        
        logHandler.info("[success]✓[end] [num]\(translations.count)[end][success] source strings pushed successfully[end]")
    }
}

/// The pull subcommand of the CLI app is responsible for downloading the latest translations from CDS
/// and creating a file that contains all translations for all locales, to be used by the Transifex Native library
/// after the file has been added in the application bundle.
struct Pull: ParsableCommand {
    @OptionGroup var options: Options

    public static let configuration = CommandConfiguration(
        commandName: "pull",
        abstract: """
Downloads translations from Transifex and stores them in a file.
""",
        discussion: """
You can provide the Transifex token via an enviroment variable (TRANSIFEX_TOKEN)
or via the --token parameter.
"""
    )

    @Option(name: .long, parsing: .upToNextOption, help: """
A list of the available locales that the application supports and will be
downloaded from CDS. The source locale, if added, is ignored.
""")
    private var translatedLocales: [String]
    
    @Option(name: .long, help: """
The folder to be used to store the generated translations file. You can use
either a relative or an absolute path. If the folder doesn't exist, the tool
will try to create it (alongside any intermediate folders).
""")
    private var output: String
    
    func run() throws {
        let logHandler = CliLogHandler()
        logHandler.verbose = options.verbose
        
        TXLogger.setHandler(handler: logHandler)
        
        guard let transifexToken = options.token ?? ProcessInfo.processInfo.environment[Options.TOKEN_ENV] else {
            logHandler.error("Missing Transifex token")
            throw CommandError.missingToken
        }
        
        logHandler.verbose("[prompt]Using token: \(transifexToken)[end]")
        
        logHandler.info("[prompt]Initializing TxNative...[end]")
        
        TXNative.initialize(locales: TXLocaleState(sourceLocale: nil,
                                                   appLocales: translatedLocales),
                            token: transifexToken,
                            secret: nil,
                            cache: TXNoOpCache())
        
        logHandler.info("[high]Fetching translations from CDS...[end]")
        
        // Block until the pull logic completes using a semaphore.
        let semaphore = DispatchSemaphore(value: 0)
        var appTranslations: [String: TXLocaleStrings] = [:]
        var appErrors: [Error] = []
        
        TXNative.fetchTranslations(nil) { (fetchedTranslations, errors) in
            appErrors = errors
            appTranslations = fetchedTranslations
            semaphore.signal()
        }
        
        semaphore.wait()
        
        guard appErrors.count == 0 else {
            logHandler.error("Errors while fetching translations from CDS: \(appErrors)")
            throw CommandError.cdsPullFailure
        }
        
        logHandler.info("""
[success]✓[end] [num]\(appTranslations.count)[end] [success]localizations fetched successfully[end]
""")
        
        var jsonData: Data?
        
        do {
            jsonData = try JSONEncoder().encode(appTranslations)
        }
        catch {
            logHandler.error("Error encoding translations: \(error)")
        }
        
        guard let serializedData = jsonData,
              let serializedTranslations = String(data: serializedData,
                                                  encoding: .utf8) else {
            logHandler.error("Error serializing translations")
            throw CommandError.translationsEncodingFailure
        }
        
        var relativeURL: URL? = nil
        
        if !output.starts(with: "/") {
            relativeURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        }
        
        let outputFolder = URL(fileURLWithPath: output,
                               relativeTo: relativeURL)
        
        do {
            try FileManager.default.createDirectory(at: outputFolder,
                                                    withIntermediateDirectories: true,
                                                    attributes: nil)
        }
        catch {
            logHandler.error("Error creating output folder: \(error)")
            throw CommandError.outputDirectoryCreationFailure
        }
        
        let outputFileURL = outputFolder.appendingPathComponent(TXNative.STRINGS_FILENAME)
        
        logHandler.info("[high]Writing file...[end]")
        
        do {
            try serializedTranslations.write(to: outputFileURL,
                                             atomically: true,
                                             encoding: .utf8)
        }
        catch {
            logHandler.error("Error writing to file: \(error)")
            throw CommandError.outputFileWritingFailure
        }
        
        logHandler.info("""
[success]✓ Translations file has been successfully generated![end]

[prompt]You can find the generated file at:[end]
[file]\(outputFileURL.path)[end]

[prompt]Copy the generated file to your Xcode project and make sure it is included in
the 'Copy Bundle Resources' build phase, so that Transifex Native library can
look it up upon your application's launch.[end]
""")
    }
}

/// The invalidate subcommand of the CLI app is responsible for invalidating the CDS cache so that any
/// subsequent pull will fetch the fresh translations from CDS.
struct Invalidate: ParsableCommand {
    @OptionGroup var options: Options

    public static let configuration = CommandConfiguration(
        commandName: "invalidate",
        abstract: "Forces CDS cache invalidation.",
        discussion: """
You can either provide the Transifex token and secret via enviroment variables
(TRANSIFEX_TOKEN, TRANSIFEX_SECRET) or via the --token and --secret parameters.
"""
    )

    func run() throws {
        let logHandler = CliLogHandler()
        logHandler.verbose = options.verbose
        
        TXLogger.setHandler(handler: logHandler)
        
        guard let transifexToken = options.token ?? ProcessInfo.processInfo.environment[Options.TOKEN_ENV] else {
            logHandler.error("Missing Transifex token")
            throw CommandError.missingToken
        }
        
        logHandler.verbose("[prompt]Using token: \(transifexToken)[end]")
        
        guard let transifexSecret = options.secret ?? ProcessInfo.processInfo.environment[Options.SECRET_ENV] else {
            logHandler.error("Missing Transifex secret")
            throw CommandError.missingSecret
        }
        
        logHandler.verbose("[prompt]Using secret: \(transifexSecret)[end]")
        
        logHandler.info("[prompt]Initializing TxNative...[end]")
        
        TXNative.initialize(locales: TXLocaleState(sourceLocale: nil,
                                                   appLocales: []),
                            token: transifexToken,
                            secret: transifexSecret,
                            cache: TXNoOpCache())
        
        logHandler.info("[high]Invalidating CDS cache...[end]")
        
        // Block until the invalidation logic completes using a semaphore.
        let semaphore = DispatchSemaphore(value: 0)
        var result = false
        
        TXNative.forceCacheInvalidation { (cacheInvalidated) in
            result = cacheInvalidated
            semaphore.signal()
        }
        
        semaphore.wait()
        
        guard result == true else {
            logHandler.error("CDS cache invalidation failed")
            throw CommandError.cdsCacheInvalidationFailure
        }
        
        logHandler.info("[success]✓ CDS cache invalidated successfully[end]")
    }
}

TXCli.main()
