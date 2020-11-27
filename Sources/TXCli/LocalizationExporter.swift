//
//  LocalizationExporter.swift
//  TXCli
//
//  Created by Stelios Petrakis on 27/11/20.
//  Copyright © 2020 Transifex. All rights reserved.
//

import Foundation

/// Manages the export of the base localization (as specified by the sourceLocale) of a Xcode project
/// via the xcodebuild -exportLocalizations command.
class LocalizationExporter {
    
    /// The source (base) locale of the project that will be used for looking up the generated XLIFF file.
    let sourceLocale: String
    
    /// The relative or absolute path to the .xcodeproj folder of the Xcode project.
    let projectName: String
    
    /// The temporary export file URL that will be used to store the exported localizations.
    private let exportURL: URL
    
    private static let TEMP_FOLDER_PREFIX = "transifexnative-"
    
    private static let LOCALIZED_CONTENTS_FOLDER_NAME = "Localized Contents"
    private static let XCLOC_EXTENSION = "xcloc"
    private static let XLIFF_EXTENSION = "xliff"
    
    /// Initializes the exporter and generates a temp directory for this session where the generated .xcloc
    /// folder will be created. Returns nil if the generated folder already exists and cannot be removed.
    ///
    /// - Parameters:
    ///   - sourceLocale: The source locale for the base localization
    ///   - projectName: The path to the project name (can be a relative path)
    init?(sourceLocale: String,
          projectName: String) {
        self.sourceLocale = sourceLocale
        self.projectName = projectName
        
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
                verboseLog("Error while removing old subfolder \(tempSubFolder): \(e)")
                return nil
            }
        }
        
        do {
            try FileManager.default.createDirectory(at: tempSubFolder,
                                                    withIntermediateDirectories: false)
        }
        catch {
            verboseLog("Error creating temp subfolder \(tempSubFolder): \(error)")
            return nil
        }
        
        self.exportURL = tempSubFolder
    }
    
    /// Removes the temporary folder that was created during the initialization process
    func cleanup() {
        verboseLog("Removing temp subfolder \(exportURL)...")

        do {
            try FileManager.default.removeItem(at: exportURL)
        }
        catch {
            verboseLog("Error removing temp subfolder \(exportURL): \(error)")
        }
    }
    
    /// Exports the base localization from the project and looks up the generated .xcloc directory for the
    /// existence of the source locale XLIFF file.
    ///
    /// - Returns: The URL to the source locale XLIFF file, nil in case of an error.
    func export() -> URL? {
        verboseLog("Exporting localizations for project \(projectName) to \(exportURL)...")
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        process.arguments = [ "-exportLocalizations",
                              "-localizationPath", exportURL.path,
                              "-project", projectName]
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
        }
        catch {
            verboseLog("Error executing xcodebuild: \(error)")
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
            verboseLog("xcodebuild output: \(output)")
        }

        let error = String(decoding: errorData, as: UTF8.self)

        if error.count > 0 {
            verboseLog("xcodebuild error: \(error)")
        }
        
        let xclocFilename = sourceLocale + "." + LocalizationExporter.XCLOC_EXTENSION
        
        let xclocURL = exportURL.appendingPathComponent(xclocFilename)
        
        guard FileManager.default.fileExists(atPath: xclocURL.path) else {
            verboseLog("Generated \(xclocFilename) not found")
            return nil
        }
        
        let xliffFilename = sourceLocale + "." + LocalizationExporter.XLIFF_EXTENSION
        
        let xliffURL = xclocURL
            .appendingPathComponent(LocalizationExporter.LOCALIZED_CONTENTS_FOLDER_NAME)
            .appendingPathComponent(xliffFilename)
        
        guard FileManager.default.fileExists(atPath: xliffURL.path) else {
            verboseLog("Generated \(xliffFilename) not found")
            return nil
        }
        
        return xliffURL
    }
}
