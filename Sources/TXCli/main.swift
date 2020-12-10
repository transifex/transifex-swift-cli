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

/// The push subcommand of the CLI app that is responsible for exporting the base localization from a Xcode
/// project, parsing the generated XLIFF file, generating the CDS-ready structure and pushing that structure
/// to CDS using the provided  credentials.
struct Push: ParsableCommand {
    private static let TOKEN_ENV = "TRANSIFEX_TOKEN"
    private static let SECRET_ENV = "TRANSIFEX_SECRET"
    
    enum PushError : Error {
        case missingToken
        case missingSecret
        case missingProjectName
        case exporterInitializationFailure
        case exportFailure
        case xliffParserInitializationFailure
        case xliffParsingFailure
        case cdsPushFailure
    }
    
    public static let configuration = CommandConfiguration(
        abstract: "Pushes translations to Transifex",
        discussion: """
You can either provide the Transifex token and secret via enviroment variables
(TRANSIFEX_TOKEN, TRANSIFEX_SECRET) or via the --token and --secret parameters.
"""
    )

    @Option(name: .long, help: "Transifex token")
    private var token: String?

    @Option(name: .long, help: "Transifex secret")
    private var secret: String?
    
    @Option(name: .long, help: "Source locale, defaults to en")
    private var sourceLocale: String = "en"

    @Option(name: .long, help: """
Path to the .xcodeproj file of the project
(e.g. ../MyProject/myproject.xcodeproj)
""")
    private var project : String?
    
    @Flag(name: .long, help: "Extra logging for debugging purposes")
    private var verbose: Bool = false

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
        TXLogger.verbose = verbose
        
        guard let transifexToken = token ?? ProcessInfo.processInfo.environment[Push.TOKEN_ENV] else {
            TXLogger.log("Missing Transifex token")
            throw PushError.missingToken
        }
        
        TXLogger.log("Using token: \(transifexToken)")
        
        guard let transifexSecret = secret ?? ProcessInfo.processInfo.environment[Push.SECRET_ENV] else {
            TXLogger.log("Missing Transifex secret")
            throw PushError.missingSecret
        }
        
        TXLogger.log("Using secret: \(transifexSecret)")
        
        guard let project = project else {
            TXLogger.log("Missing project name")
            throw PushError.missingProjectName
        }
        
        guard let localizationExporter = LocalizationExporter(sourceLocale: sourceLocale,
                                                              project: project) else {
            TXLogger.log("Failed to initialize localization exporter")
            throw PushError.exporterInitializationFailure
        }
        
        defer {
            if !keepTempFolder {
                localizationExporter.cleanup()
            }
        }
        
        guard let xliffURL = localizationExporter.export() else {
            TXLogger.log("Localization export failed")
            throw PushError.exportFailure
        }
        
        guard let parser = XLIFFParser(fileURL: xliffURL) else {
            TXLogger.log("Failed to initialize XLIFF parser")
            throw PushError.xliffParserInitializationFailure
        }
        
        if !parser.parse() {
            TXLogger.log("XLIFF parsing failed")
            throw PushError.xliffParsingFailure
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
                            secret: transifexSecret)
        
        TXLogger.log("Pushing translations to CDS...")
        
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
            throw PushError.cdsPushFailure
        }
        
        print("Localizations pushed successfully")
    }
}

/// Base command of TXCli app, this command describes the basic usage of the CLI app and lists all
/// subcommands (e.g. push).
struct TXCli: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "transifex",
        abstract: "A command-line tool to push iOS translations to Transifex",
        discussion: """
You can use Transifex Command Line Tool to export, parse and push the base
localizations of your Xcode application to Transifex.
""",
        version: "0.1",
        subcommands: [Push.self])
}

TXCli.main()
