//
//  main.swift
//  TXCli
//
//  Created by Stelios Petrakis on 27/11/20.
//  Copyright © 2020 Transifex. All rights reserved.
//

import TransifexNative
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
}

/// Base command of TXCli app, this command describes the basic usage of the CLI app and lists all
/// subcommands.
struct TXCli: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "transifex",
        abstract: """
A command-line tool to push iOS translations to Transifex or download existing
translations and transform them into ready to use assets that can be copied in
the app bundle.
""",
        discussion: """
You can use Transifex Command Line Tool to push the base localization of your
Xcode application to Transifex or download the translations of your Xcode
application so that they can be added in the app bundle and used by the
Transifex native library.
""",
        version: "0.2",
        subcommands: [Push.self, Pull.self])
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

/// The push subcommand of the CLI app that is responsible for exporting the base localization from a Xcode
/// project, parsing the generated XLIFF file, generating the CDS-ready structure and pushing that structure
/// to CDS using the provided  credentials.
struct Push: ParsableCommand {
    @OptionGroup var options: Options

    public static let configuration = CommandConfiguration(
        abstract: "Pushes translations to Transifex",
        discussion: """
You can either provide the Transifex token and secret via enviroment variables
(TRANSIFEX_TOKEN, TRANSIFEX_SECRET) or via the --token and --secret parameters.
"""
    )
    
    @Option(name: .long, help: "Source locale, defaults to en")
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
    
    func run() throws {
        TXLogger.verbose = options.verbose
        
        guard let transifexToken = options.token ?? ProcessInfo.processInfo.environment[Options.TOKEN_ENV] else {
            TXLogger.log("Missing Transifex token")
            throw CommandError.missingToken
        }
        
        TXLogger.log("Using token: \(transifexToken)")
        
        guard let transifexSecret = options.secret ?? ProcessInfo.processInfo.environment[Options.SECRET_ENV] else {
            TXLogger.log("Missing Transifex secret")
            throw CommandError.missingSecret
        }
        
        TXLogger.log("Using secret: \(transifexSecret)")
        
        guard let localizationExporter = LocalizationExporter(sourceLocale: sourceLocale,
                                                              project: project) else {
            TXLogger.log("Failed to initialize localization exporter")
            throw CommandError.exporterInitializationFailure
        }
        
        defer {
            if !keepTempFolder {
                localizationExporter.cleanup()
            }
        }
        
        guard let xliffURL = localizationExporter.export() else {
            TXLogger.log("Localization export failed")
            throw CommandError.exportingFailure
        }
        
        guard let parser = XLIFFParser(fileURL: xliffURL) else {
            TXLogger.log("Failed to initialize XLIFF parser")
            throw CommandError.xliffParserInitializationFailure
        }
        
        if !parser.parse() {
            TXLogger.log("XLIFF parsing failed")
            throw CommandError.xliffParsingFailure
        }
        
        var translations: [TxSourceString] = []
        var occurrences: [String:[String]] = [:]
        var addedKeys: [String] = []
        
        // Group occurrences based on the key id
        for result in parser.results {
            let key = generateKey(sourceString: result.id,
                                  context: nil)

            if occurrences[key] == nil {
                occurrences[key] = []
            }
            
            occurrences[key]?.append(result.file)
        }
        
        for result in parser.results {
            let key = generateKey(sourceString: result.id,
                                  context: nil)
            
            // Do not add the same key twice, occurrences is used for that
            guard !addedKeys.contains(key) else {
                continue
            }
            
            addedKeys.append(key)
            
            let keyOccurrences = occurrences[key] ?? []
            
            let translationUnit = TxSourceString(key: key,
                                                 sourceString: result.source,
                                                 occurrences: keyOccurrences,
                                                 characterLimit: 0,
                                                 developerComment: result.note)
            translations.append(translationUnit)
        }

        TXLogger.log("Initializing TxNative...")
        
        TxNative.initialize(locales: LocaleState(sourceLocale: sourceLocale),
                            token: transifexToken,
                            secret: transifexSecret,
                            cache: TXNoOpCache())
        
        TXLogger.log("Pushing translations to CDS (Purge: \(purge ? "Yes" : "No"))...")
        
        // Block until the push logic completes using a semaphore.
        let semaphore = DispatchSemaphore(value: 0)
        var pushResult = false
        TxNative.pushTranslations(translations,
                                  purge: purge) { (result) in
            pushResult = result
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if !pushResult {
            print("Error while pushing localizations to CDS")
            throw CommandError.cdsPushFailure
        }
        
        print("Localizations pushed successfully")
    }
}

/// The pull subcommand of the CLI app that is responsible for downloading the latest translations from CDS
/// and creating a file that contains all translations for all locales, to be used by the Transifex Native library
/// after the file has been added in the application bundle.
struct Pull: ParsableCommand {
    @OptionGroup var options: Options

    public static let configuration = CommandConfiguration(
        abstract: """
Downloads translations to Transifex and stores them into a file that can be
imported in the Xcode project of the application using Transifex Native library.
""",
        discussion: """
You can either provide the Transifex token and secret via enviroment variables
(TRANSIFEX_TOKEN, TRANSIFEX_SECRET) or via the --token and --secret parameters.
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
        TXLogger.verbose = options.verbose
        
        guard let transifexToken = options.token ?? ProcessInfo.processInfo.environment[Options.TOKEN_ENV] else {
            TXLogger.log("Missing Transifex token")
            throw CommandError.missingToken
        }
        
        TXLogger.log("Using token: \(transifexToken)")
        
        guard let transifexSecret = options.secret ?? ProcessInfo.processInfo.environment[Options.SECRET_ENV] else {
            TXLogger.log("Missing Transifex secret")
            throw CommandError.missingSecret
        }
        
        TXLogger.log("Using secret: \(transifexSecret)")
        
        TXLogger.log("Initializing TxNative...")
        
        TxNative.initialize(locales: LocaleState(sourceLocale: nil,
                                                 appLocales: translatedLocales),
                            token: transifexToken,
                            secret: transifexSecret,
                            cache: TXNoOpCache())
        
        TXLogger.log("Fetching translations from CDS...")
        
        // Block until the pull logic completes using a semaphore.
        let semaphore = DispatchSemaphore(value: 0)
        var appTranslations: [String: TXLocaleStrings] = [:]
        var appErrors: [Error] = []
        
        TxNative.fetchTranslations(nil) { (fetchedTranslations, errors) in
            appErrors = errors
            appTranslations = fetchedTranslations
            semaphore.signal()
        }
        
        semaphore.wait()
        
        guard appErrors.count == 0 else {
            TXLogger.log("Error(s) while fetching translations from CDS: \(appErrors)")
            throw CommandError.cdsPullFailure
        }
        
        TXLogger.log("\(appTranslations.count) localization(s) fetched successfully")
        
        var jsonData: Data?
        
        do {
            jsonData = try JSONEncoder().encode(appTranslations)
        }
        catch {
            TXLogger.log("Error encoding translations: \(error)")
        }
        
        guard let serializedData = jsonData,
              let serializedTranslations = String(data: serializedData,
                                                  encoding: .utf8) else {
            TXLogger.log("Error serializing translations")
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
            TXLogger.log("Error creating output folder: \(error)")
            throw CommandError.outputDirectoryCreationFailure
        }
        
        let outputFileURL = outputFolder.appendingPathComponent(TxNative.STRINGS_FILENAME)
        
        TXLogger.log("Writing file...")
        
        do {
            try serializedTranslations.write(to: outputFileURL,
                                             atomically: true,
                                             encoding: .utf8)
        }
        catch {
            TXLogger.log("Error writing to file: \(error)")
            throw CommandError.outputFileWritingFailure
        }
        
        print("""
Translations file has been successfully generated!

Instructions:

You can find the generated file at:
\(outputFileURL.path)

Copy the generated file to your Xcode project and make sure it is included in
the 'Copy Bundle Resources' build phase, so that Transifex Native library can
look it up upon your application's launch.
""")
    }
}

TXCli.main()
