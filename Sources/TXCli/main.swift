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
import CLISpinner

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
        version: "1.0.6",
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
Either the path to the project's .xcodeproj or .xcworkspace (e.g. ../MyProject/myproject.xcodeproj),
or the path to the generated .xliff (e.g. ../en.xliff).
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
    private var appendTags: [String] = []
    
    @Flag(name: .long, help: "Do not push to CDS.")
    private var dryRun: Bool = false
    
    @Flag(name: .long, inversion: .prefixedEnableDisable,
          exclusivity: .exclusive, help: """
Control whether the keys of strings to be pushed should be hashed (true) or not
(false).
""")
    private var hashKeys: Bool = true

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
        
        var xliffURL : URL? = nil
        let projectURL = URL(fileURLWithPath: project)
        
        var localizationExporter : LocalizationExporter? = nil
        
        defer {
            if !keepTempFolder {
                localizationExporter?.cleanup()
            }
        }
        
        if projectURL.pathExtension == "xliff" {
            xliffURL = projectURL
            logHandler.verbose("[prompt]XLIFF file detected: \(xliffURL!)[end]")
        }
        else {
            guard let locExporter = LocalizationExporter(sourceLocale: sourceLocale,
                                                         project: projectURL,
                                                         logHandler: logHandler) else {
                logHandler.error("Failed to initialize localization exporter")
                throw CommandError.exporterInitializationFailure
            }
        
            localizationExporter = locExporter
        
            guard let exportXliffURL = localizationExporter?.export() else {
                logHandler.error("Localization export failed")
                throw CommandError.exportingFailure
            }
            
            xliffURL = exportXliffURL
        }
        
        guard let fileURL = xliffURL else {
            logHandler.error("Localization export failed")
            throw CommandError.exportingFailure
        }
        
        guard let parser = XLIFFParser(fileURL: fileURL,
                                       logHandler: logHandler) else {
            logHandler.error("Failed to initialize XLIFF parser")
            throw CommandError.xliffParserInitializationFailure
        }
        
        if !parser.parse() {
            logHandler.error("XLIFF parsing failed")
            throw CommandError.xliffParsingFailure
        }
        
        let filteredResults = XLIFFParser.filter(parser.results)

        var translations: [TXSourceString] = []
        
        for result in XLIFFParser.consolidate(filteredResults) {
            let key = hashKeys ? txGenerateKey(sourceString: result.id,
                                               context: nil) : result.id
            
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
                                                 tags: appendTags)
            
            // Do not add the same key twice, occurrences is used for that
            guard !translations.contains(translationUnit) else {
                continue
            }
            
            translations.append(translationUnit)
        }
        
        logHandler.info("""
[high]Found[end] [num]\(translations.count)[end] [high]source strings[end]
""")
        
        guard dryRun == false else {
            logHandler.warning("[warn]Dry run: no strings will be pushed to CDS")
            
            logHandler.verbose("Translations: \(translations.debugDescription)")
            return
        }

        logHandler.verbose("[high]Initializing TxNative...[end]")
        
        TXNative.initialize(locales: TXLocaleState(sourceLocale: sourceLocale),
                            token: transifexToken,
                            secret: transifexSecret,
                            cache: TXNoOpCache())
        
        logHandler.info("""
[high]Pushing[end] [num]\(translations.count)[end] [high]source strings to CDS ([end][prompt]Purge: \(purge ? "Yes" : "No")[end][high])...[end]
""")
        
        let spinner = Spinner(pattern: .dots, text: "Pushing")
        if !options.verbose {
            spinner.start()
        }
        
        // Block until the push logic completes using a semaphore.
        let semaphore = DispatchSemaphore(value: 0)
        var pushResult = false
        var pushErrors: [Error] = []
        var pushWarnings: [Error] = []
        
        TXNative.pushTranslations(translations,
                                  purge: purge) { (result, errors, warnings) in
            pushResult = result
            pushErrors = errors
            pushWarnings = warnings
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if !options.verbose {
            spinner.stopAndClear()
        }
        
        for pushWarning in pushWarnings {
            guard let warning = pushWarning as? TXCDSWarning else {
                logHandler.warning("Generic warning encountered: \(pushWarning)",
                                   trailingLine: true)
                continue
            }
            switch warning {
            case .duplicateSourceString(sourceString: let sourceString,
                                        duplicate: let duplicate):
                logHandler.warning("""
Warning: Duplicate source string pair found:
>> \(sourceString)
<< \(duplicate)
""", trailingLine: true)
            case .emptyKey(SourceString: let sourceString):
                logHandler.warning("""
Warning: Empty key on source string:
\(sourceString)
""", trailingLine: true)
            }
        }

        for pushError in pushErrors {
            guard let error = pushError as? TXCDSError else {
                logHandler.error("Generic error encountered: \(pushError)",
                                 trailingLine: true)
                continue
            }
            switch error {
            case .noDataToBeSent:
                logHandler.error("Error encoding source strings",
                                 trailingLine: true)

            case .invalidCDSURL:
                logHandler.error("Error: Invalid CDS host URL:",
                                 trailingLine: true)

            case .failedSerialization(let err):
                logHandler.error("Error while serializing translations: \(err)",
                                 trailingLine: true)

            case .requestFailed(let err):
                logHandler.error("Error pushing strings: \(err)",
                                 trailingLine: true)

            case .invalidHTTPResponse:
                logHandler.error("Error pushing strings: Not a valid HTTP response",
                                 trailingLine: true)

            case .serverError(let statusCode):
                logHandler.error("HTTP Status error while pushing strings: \(statusCode)",
                                 trailingLine: true)

            case .noData:
                logHandler.error("Error: No data received while pushing strings",
                                 trailingLine: true)

            case .nonParsableResponse:
                logHandler.error("Error while decoding CDS push response",
                                 trailingLine: true)

            case .failedJobRequest:
                logHandler.error("Error: Fetch job status request failed",
                                 trailingLine: true)

            case .maxRetriesReached:
                logHandler.info("[prompt]Strings are queued for processing[end]")

            case .jobError(status: let status,
                           code: let code,
                           title: let title,
                           detail: let detail,
                           source: let source):
                logHandler.error("""
Error: \(title) (\(status) - \(code)):
Detail: \(detail)
Source: \(source)
""", trailingLine: true)

            default:
                logHandler.error("Error while pushing source strings to CDS",
                                 trailingLine: true)
            }
        }

        if pushResult {
            logHandler.info("""
[success]✓ Source strings pushed successfully[end]
""")
        }
    }
    
    /// Reports whether the passed array of errors contains a max retries reached error or not.
    ///
    /// - Parameter errors: Passed array of errors as returned by the pushTranslations() method
    /// - Returns: true if the array contains a max retries reached error, false otherwise
    func containsMaxRetriesReachedError(_ errors: [Error]) -> Bool {
        guard errors.count > 0 else {
            return false
        }
        
        for error in errors {
            if case TXCDSError.maxRetriesReached = error {
                return true
            }
        }
        
        return false
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
downloaded from CDS. If both source and target locales are provided in the list,
they will also be requested from CDS.
""")
    private var translatedLocales: [String]
    
    @Option(name: .long, help: """
The folder to be used to store the generated translations file. You can use
either a relative or an absolute path. If the folder doesn't exist, the tool
will try to create it (alongside any intermediate folders).
""")
    private var output: String
    
    @Option(name: .long, parsing: .upToNextOption, help: """
If set, only the strings that have all of the given tags will be downloaded.

This option can be used alongside the --with-status-only option.
""")
    private var withTagsOnly: [String] = []
    
    @Option(name: .long, help: """
If set, only the strings that have the provided status assigned will be
downloaded.

This option can be used alongside the --with-tags-only option.
""")
    private var withStatusOnly: String?

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
        
        let spinner = Spinner(pattern: .dots, text: "Fetching")
        if !options.verbose {
            spinner.start()
        }
        
        // Block until the pull logic completes using a semaphore.
        let semaphore = DispatchSemaphore(value: 0)
        var appTranslations: [String: TXLocaleStrings] = [:]
        var appErrors: [Error] = []
        
        TXNative.fetchTranslations(tags: withTagsOnly,
                                   status: withStatusOnly) { (fetchedTranslations, errors) in
            appErrors = errors
            appTranslations = fetchedTranslations
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if !options.verbose {
            spinner.stopAndClear()
        }
        
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
