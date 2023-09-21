//
//  LocalizationExporter.swift
//  TXCli
//
//  Created by Stelios Petrakis on 27/11/20.
//  Copyright © 2020 Transifex. All rights reserved.
//

import Foundation
import Transifex

/// Manages the export of the base localization (as specified by the sourceLocale) of a Xcode project
/// via the xcodebuild -exportLocalizations command.
public class LocalizationExporter {
    /// The source (base) locale of the project that will be used for looking up the generated XLIFF file.
    let sourceLocale: String
    
    /// The relative or absolute file URL to the .xcodeproj or .xcworkspace folder of the Xcode project.
    let project: URL
    
    /// The temporary export file URL that will be used to store the exported localizations.
    private let exportURL: URL
    
    private static let TEMP_FOLDER_PREFIX = "txios-cli-"
    
    private static let LOCALIZED_CONTENTS_FOLDER_NAME = "Localized Contents"
    private static let XCLOC_EXTENSION = "xcloc"
    private static let XLIFF_EXTENSION = "xliff"

    private static let IOS_LANGUAGE_TAG_DELIMITER = "-"
    private static let TRANSIFEX_LANGUAGE_TAG_DELIMITER = "_"

    private let logHandler: TXLogHandler?
    
    /// Initializes the exporter and generates a temp directory for this session where the generated .xcloc
    /// folder will be created. Returns nil if the generated folder already exists and cannot be removed.
    ///
    /// - Parameters:
    ///   - sourceLocale: The source locale for the base localization
    ///   - project: The path to the project name (can be a relative path)
    ///   - logHandler: Optional log handler
    public init?(sourceLocale: String,
                 project: URL,
                 logHandler: TXLogHandler? = nil) {
        guard project.pathExtension == "xcodeproj"
                || project.pathExtension == "xcworkspace" else {
            logHandler?.error("Error: project parameter is not a .xcodeproj or .xcworkspace")
            return nil
        }

        /// Ensure that the exported XLOC and XLIFF containers will be accessible for the source locale,
        /// as the iOS uses a hyphen for the language tag (e.g. en-GB) while Transifex uses an
        /// underscore (e.g. en_GB).
        let normalizedLocaleCode = sourceLocale.replacingOccurrences(of: Self.TRANSIFEX_LANGUAGE_TAG_DELIMITER,
                                                                     with: Self.IOS_LANGUAGE_TAG_DELIMITER)

        self.sourceLocale = normalizedLocaleCode
        self.project = project
        self.logHandler = logHandler

        let uuidString = UUID().uuidString
        let tempExportURLPath = LocalizationExporter.TEMP_FOLDER_PREFIX + uuidString
        
        let tempFolder = URL(fileURLWithPath: NSTemporaryDirectory(),
                             isDirectory: true)
        
        let tempSubFolder = tempFolder.appendingPathComponent(tempExportURLPath,
                                                              isDirectory: true)

        do {
            try FileManager.default.removeItem(at: tempSubFolder)
        }
        catch {
            let e = error as NSError
            if e.domain == NSCocoaErrorDomain,
               e.code == NSFileNoSuchFileError {
                // We don't care about "No such file or directory" errors.
            }
            else {
                logHandler?.error("Error while removing old subfolder \(tempSubFolder.path): \(e)")
                return nil
            }
        }
        
        do {
            try FileManager.default.createDirectory(at: tempSubFolder,
                                                    withIntermediateDirectories: false)
        }
        catch {
            logHandler?.error("Error creating temp subfolder \(tempSubFolder.path): \(error)")
            return nil
        }
        
        self.exportURL = tempSubFolder
    }
    
    /// Removes the temporary folder that was created during the initialization process
    public func cleanup() {
        logHandler?.verbose("[prompt]Removing temp subfolder[end] [file]\(exportURL.path)[end][prompt]...[end]")

        do {
            try FileManager.default.removeItem(at: exportURL)
        }
        catch {
            logHandler?.error("Error removing temp subfolder \(exportURL.path): \(error)")
        }
    }
    
    /// Exports the base localization from the project and looks up the generated .xcloc directory for the
    /// existence of the source locale XLIFF file.
    ///
    /// - Returns: The URL to the source locale XLIFF file, nil in case of an error.
    public func export() -> URL? {
        logHandler?.verbose("[prompt]Exporting localizations for project \(project) to[end] [file]\(exportURL.path)[end][prompt]...[end]")
        
        let isProject = project.pathExtension == "xcodeproj"
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        process.arguments = [ "-exportLocalizations",
                              "-localizationPath", exportURL.path,
                              isProject ? "-project" : "-workspace", project.path]
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
        }
        catch {
            logHandler?.error("""
Error executing xcodebuild:
\(error)
""")
            return nil
        }

        // We need to block until we read the output pipe data so that we wait
        // for the xcodebuild command to finish executing.
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        // We log the output and error pipes when verbose logging is enabled,
        // but we treat the errors that might have been generated during
        // the localization export phase, as 'soft'.
        //
        // For example, because the `xcodebuild -exportLocalizations` command
        // uses the `genstrings` internally, the latter may generate warnings
        // or errors that are written to the standard error file descriptor and
        // may not result to a general failure.
        //
        // We only trigger a failure if the generated directories or files do
        // not exist.
        let output = String(decoding: outputData, as: UTF8.self)

        if output.count > 0 {
            logHandler?.verbose("""
[warn]xcodebuild output:[end]
[warn]\(output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))[end]
""")
        }

        let error = String(decoding: errorData, as: UTF8.self)

        if error.count > 0 {
            logHandler?.verbose("""
xcodebuild error:
\(error.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
""")
        }
        
        let xclocFilename = sourceLocale + "." + LocalizationExporter.XCLOC_EXTENSION
        
        let xclocURL = exportURL.appendingPathComponent(xclocFilename)
        
        guard FileManager.default.fileExists(atPath: xclocURL.path) else {
            logHandler?.error("Generated \(xclocFilename) not found")
            return nil
        }
        
        let xliffFilename = sourceLocale + "." + LocalizationExporter.XLIFF_EXTENSION
        
        let xliffURL = xclocURL
            .appendingPathComponent(LocalizationExporter.LOCALIZED_CONTENTS_FOLDER_NAME)
            .appendingPathComponent(xliffFilename)
        
        guard FileManager.default.fileExists(atPath: xliffURL.path) else {
            logHandler?.error("Generated \(xliffFilename) not found")
            return nil
        }
        
        return xliffURL
    }
}
