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
enum CommandError : Error, CustomStringConvertible {
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
    
    // Human-readable error codes
    public var description: String {
        switch self {
        case .missingToken:
            return "Token is missing"
        case .missingSecret:
            return "Secret is missing"
        case .exporterInitializationFailure:
            return "Exporter failed to initialize"
        case .exportingFailure:
            return "Exporting failed"
        case .xliffParserInitializationFailure:
            return "XLIFF parser failed to initialze"
        case .xliffParsingFailure:
            return "XLIFF parsong failed"
        case .cdsPushFailure:
            return "Push to CDS failed"
        case .cdsPullFailure:
            return "Pull from CDS failed"
        case .translationsEncodingFailure:
            return "Encoding failure encountered when processing translations"
        case .outputDirectoryCreationFailure:
            return "Creation of output directory failed"
        case .outputFileWritingFailure:
            return "Writing to the output file failed"
        case .cdsCacheInvalidationFailure:
            return "CDS cache invalidation failed"
        }
    }
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
        version: "2.1.6",
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
    
    @Option(name: .long, help: """
Change the source locale if it is different than 'en'.

e.g. --source-locale en_GB
""")
    private var sourceLocale: String = "en"

    @Option(name: .long, help: """
Optional name or path of the base SDK to be used when exporting project's
localizations.

e.g.
--base-sdk macosx
--base-sdk iphoneos17.0
--base-sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS18.2.sdk
""")
    private var baseSDK: String?

    @Option(name: .long, help: """
The absolute or relative path to the project's .xcodeproj , .xcworkspace or to
the generated .xliff.

e.g. 
--project ../MyProject/myproject.xcodeproj
--project ../MyProject/myproject.xcworkspace
--project ../en.xliff
""")
    private var project : String
    
    @Flag(name: .long, help: """
Whether to keep the temporary folder that contains the generated .xcloc or not.
""")
    private var keepTempFolder: Bool = false
    
    @Option(name: .long, parsing: .upToNextOption, help: """
Optional space-separated list of global tags to be included in all source
strings pushed to the CDS server.

e.g. --append-tags master react
""")
    private var appendTags: [String] = []
    
    @Option(name: .long, parsing: .upToNextOption, help: """
Optional space-separated list of localizable files that the logic must exclude
when processing the exported strings.

e.g. --excluded-files target1/Info.strings target2/Info.strings
""")
    private var excludedFiles: [String] = []

    @Flag(name: .long, inversion: .prefixedEnableDisable,
          exclusivity: .exclusive, help: """
Control whether the keys of strings to be pushed should be hashed (true) or not
(false).
""")
    private var hashKeys: Bool = false

    @Flag(name: .long, help: """
If --purge is specified, then the logic replaces the entire resource content
with the pushed content of this request.

If --purge is not specified, then the logic appends the source content of this
request to the existing resource content.
""")
    private var purge: Bool = false

    @Flag(name: .long, help: """
If --override-tags is specified, then the logic replaces the existing string
tags with the tags of this request.

If --override-tags is not specified, then the logic appends the tags from the 
source content of this request to the tags of existing strings instead of
overwriting them.
""")
    private var overrideTags: Bool = false

    @Flag(name: .long, help: """
If --override-occurrences is specified, then the logic replaces the existing
string occurrences with the occurrences of this request.

If --override-occurrences is not specified, then the logic appends the
occurrences from the source content of this request to the occurrences of the
existing strings instead of overwriting them.
""")
    private var overrideOccurrences: Bool = false

    @Flag(name: .long, help: """
If --delete-translations is specified, then the logic deletes the translations
on source string content updates.

If --delete-translation is not specified, then the logic preserves the
translations on source content updates.
""")
    private var deleteTranslations: Bool = false

    @Flag(name: .long, help: """
Emulate a content push, without performing any actual changes.
""")
    private var dryRun: Bool = false

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
                                                         baseSDK: baseSDK,
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
        
        var excludeFilenames = XLIFFParser.UNSUPPORTED_FILES
        excludeFilenames.append(contentsOf: excludedFiles)

        let filteredResults = XLIFFParser.filter(parser.results,
                                                 excludeFilenames: excludeFilenames,
                                                 logHandler: logHandler)

        var translations: [TXSourceString] = []
        
        for result in XLIFFParser.consolidate(filteredResults) {
            let key = hashKeys ? txGenerateKey(sourceString: result.id,
                                               context: nil) : result.id
            
            // Get the .target instead of the .source of the result as user
            // might have localized the string for the base locale.
            var sourceString = result.target
            
            // If the result contains string dict elements, convert them to
            // ICU format and use that as a source string
            switch result.generateICURuleIfPossible() {
            case .success((let icuRule, let icuRuleType)):
                if icuRuleType == TranslationUnit.ICURuleType.Other {
                    logHandler.error("Error: ICU rule type could not be detected.")
                    // Do not add a translation unit in case of a non-detected
                    // ICU rule type.
                    continue
                }
                sourceString = icuRule
            case .failure(let error):
                switch error {
                case .noRules:
                    break
                default:
                    logHandler.error("Error: \(error)")
                    // Do not add a translation unit in case of an error.
                    continue
                }
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
        
        let configuration = TXPushConfiguration(purge: purge,
                                                overrideTags: overrideTags,
                                                overrideOccurrences: overrideOccurrences,
                                                keepTranslations: !deleteTranslations,
                                                dryRun: dryRun)

        logHandler.verbose("Push configuration: \(configuration.debugDescription)")

        TXNative.pushTranslations(translations,
                                  configuration: configuration) { (result, errors, warnings) in
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
            logHandler.error("\(error)",
                             trailingLine: true)
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
A space-separated list of the available locales that the application supports 
and will be downloaded from CDS. 
If both source and target locales are provided in the list, they will also be
requested from CDS.

e.g. --translated-locales en el fr
""")
    private var translatedLocales: [String]
    
    @Option(name: .long, help: """
The folder to be used to store the generated translations file. You can use
either a relative or an absolute path. If the folder doesn't exist, the tool
will try to create it (alongside any intermediate folders).

e.g. --output ~/Desktop/
""")
    private var output: String
    
    @Option(name: .long, parsing: .upToNextOption, help: """
Optional space-separated list that if provided, only the strings containing
all of the specified tags will be downloaded.

This option can be used alongside the --with-status-only option.

e.g. --with-tags-only master react
""")
    private var withTagsOnly: [String] = []
    
    @Option(name: .long, help: """
Optional value that if provided, only the strings that have the specified
status assigned will be downloaded.

This option can be used alongside the --with-tags-only option.

e.g. --with-status-only translated
""")
    private var withStatusOnly: String?

    @Option(name: .long, help: """
Change the source locale if it is different than 'en'.

e.g. --source-locale en_GB
""")
    private var sourceLocale: String = "en"
    
    @Flag(name: .long, help: """
Attempt to generate the translations file even if some of the requested locales
are missing.
""")
    private var ignoreMissingLocales: Bool = false

    private static let HTTP_STATUS_CODE_NOT_FOUND = 404

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
        
        TXNative.initialize(locales: TXLocaleState(sourceLocale: sourceLocale,
                                                   appLocales: translatedLocales),
                            token: transifexToken,
                            secret: nil,
                            cache: TXNoOpCache())
        
        logHandler.info("[high]Fetching translations from CDS...[end]")
        
        // Defer log reporting until the pull logic completes
        logHandler.deferred = true

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

        // Stop log message deferring and report any deferred logs
        logHandler.deferred = false

        // Fetch result contained errors
        if appErrors.count > 0 {
            // If user has not opted in ignoring missing locales (defaults to
            // false), then throw an error immediately.
            guard ignoreMissingLocales else {
                throw CommandError.cdsPullFailure
            }

            // Check if the produced errors are only missing locale errors,
            // otherwise we need to throw an error immediately.
            let missingLocaleErrors = appErrors.filter { error in
                if let cdsError = error as? TXCDSError,
                      case .serverError(let statusCode, _) = cdsError,
                      statusCode == Self.HTTP_STATUS_CODE_NOT_FOUND {
                            return true
                      }
                return false
            }
            
            if missingLocaleErrors.count < appErrors.count {
                throw CommandError.cdsPullFailure
            }
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
