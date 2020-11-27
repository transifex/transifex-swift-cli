//
//  main.swift
//  TXCli
//
//  Created by Stelios Petrakis on 27/11/20.
//  Copyright © 2020 Transifex. All rights reserved.
//

import TransifexNative
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

    @Option(name: .long, help: "Path to the .xcodeproj file of the project (e.g. ../MyProject/myproject.xcodeproj)")
    private var projectName : String?
    
    @Flag(name: .long, help: "Extra logging for debugging purposes")
    private var verbose: Bool = false

    func run() throws {
        TXCli.verbose = verbose
        
        guard let transifexToken = token ?? ProcessInfo.processInfo.environment[Push.TOKEN_ENV] else {
            verboseLog("Missing Transifex token")
            throw PushError.missingToken
        }
        
        verboseLog("Using token: \(transifexToken)")
        
        guard let transifexSecret = secret ?? ProcessInfo.processInfo.environment[Push.SECRET_ENV] else {
            verboseLog("Missing Transifex secret")
            throw PushError.missingSecret
        }
        
        verboseLog("Using secret: \(transifexSecret)")
        
        guard let projectName = projectName else {
            verboseLog("Missing project name")
            throw PushError.missingProjectName
        }
        
        guard let localizationExporter = LocalizationExporter(sourceLocale: sourceLocale,
                                                              projectName: projectName) else {
            verboseLog("Failed to initialize localization exporter")
            throw PushError.exporterInitializationFailure
        }
        
        defer {
            localizationExporter.cleanup()
        }
        
        guard let xliffURL = localizationExporter.export() else {
            verboseLog("Localization export failed")
            throw PushError.exportFailure
        }
        
        guard let parser = XLIFFParser(fileURL: xliffURL) else {
            verboseLog("Failed to initialize XLIFF parser")
            throw PushError.xliffParserInitializationFailure
        }
        
        if !parser.parse() {
            verboseLog("XLIFF parsing failed")
            throw PushError.xliffParsingFailure
        }
        
        // TODO: Create a CDS ready structure to be fed into TxNative for
        // pushing the strings to CDS.
        for result in parser.results {
            verboseLog("\(result)")
        }
        
        // TODO: Initialize TxNative and push strings to CDS
        //verboseLog("Initializing TxNative")
        //
        //TxNative.initialize(locales: LocaleState(sourceLocale: sourceLocale),
        //                    token: transifexToken,
        //                    secret: transifexSecret)
    }
}

/// Base command of TXCli app, this command describes the basic usage of the CLI app and lists all
/// subcommands (e.g. push).
struct TXCli: ParsableCommand {
    
    /// Helper flag that's used by the `verboseLog` method.
    static var verbose: Bool = false

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
