//
//  XLIFFParser.swift
//  TXCli
//
//  Created by Stelios Petrakis on 27/11/20.
//  Copyright © 2020 Transifex. All rights reserved.
//

import Foundation
import Transifex

/// Structure that holds all the information about a pluralization rule exported from the XLIFF file being
/// parsed.
public struct PluralizationRule {
    private var components: [String]
    
    var sourceString: String!
    var pluralKey: String?
    var pluralRule: String?
    var containsLocalizedFormatKey: Bool

    var source: String?
    var target: String?
    var note: String?
    
    /// Initializes the structure with the id attribute found in the `trans-unit` XML tag of the XLIFF
    /// file.
    ///
    /// From this id, the components are extracted (via the `extractComponents` static method) and
    /// the properties are initialized:
    ///
    /// For example, if the id is the following:
    /// "/unit-time.%d-minute(s):dict/d_unit_time:dict/one:dict/:string"
    ///
    /// Then the properties have the following values:
    /// sourceString: "/unit-time.%d-minute(s)"
    /// pluralKey: "d_unit_time"
    /// pluralRule: "one"
    /// containsLocalizedFormatKey: false
    ///
    /// - Parameter id: The id attribute
    init?(with id: String) {
        let components = PluralizationRule.extractComponents(from: id)
        
        if components.count < 2 {
            return nil
        }
        
        self.components = components
        self.sourceString = components.first!
        self.containsLocalizedFormatKey = id.contains("NSStringLocalizedFormatKey")
        
        if self.containsLocalizedFormatKey {
            return
        }
        
        self.pluralKey = components[1]
        
        if self.components.count > 2 {
            self.pluralRule = self.components[2]
        }
    }
    
    mutating func updateSource(_ inSource: String) {
        source = (source ?? "") + inSource
    }
    
    mutating func updateTarget(_ inTarget: String) {
        target = (target ?? "") + inTarget
    }
    
    mutating func updateNote(_ inNote: String) {
        note = (note ?? "") + inNote
    }
    
    /// Parses the id attribute of the `trans-unit` XML tag, removes the types and trims the slash
    /// characters and then splits the string into components that each represents a certain property to
    /// be used during the initialization of the `PluralizationRule`
    ///
    /// e.g:
    /// For id:
    /// "/unit-time.%d-minute(s):dict/d_unit_time:dict/one:dict/:string"
    /// The components returned are:
    /// [ "unit-time.%d-minute(s)", "d_unit_time", "one"]
    ///
    /// - Parameter id: The id attribute
    /// - Returns: The components that define this pluralization rule
    static private func extractComponents(from id: String) -> [String] {
        return id
            .replacingOccurrences(of: ":dict", with: "")
            .replacingOccurrences(of: ":string", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .components(separatedBy: "/")
    }
    
    /// Checks whether two pluralization rules have the same source string.
    ///
    /// Important when deciding whether a pluralization rule is part of the same `TranslationUnit`.
    ///
    /// - Parameter otherPluralizationRule: The other pluralization rule
    /// - Returns: true if the `sourceString` properties are equal, false otherwise
    func hasSameSourceString(with otherPluralizationRule: PluralizationRule) -> Bool {
        return self.sourceString == otherPluralizationRule.sourceString
    }
}

extension PluralizationRule: Equatable {
    static public func ==(lhs: PluralizationRule, rhs: PluralizationRule) -> Bool {
        return lhs.sourceString == rhs.sourceString &&
            lhs.containsLocalizedFormatKey == rhs.containsLocalizedFormatKey &&
            lhs.pluralKey == rhs.pluralKey &&
            lhs.pluralRule == rhs.pluralRule &&
            lhs.source == rhs.source &&
            lhs.target == rhs.target &&
            lhs.note == rhs.note
    }
}

/// Structure that holds all the information for the translation units from a parsed XLIFF file.
public struct TranslationUnit {
    public var id: String
    public var source: String
    public var target: String
    public var files: [String] = []
    public var note: String?
    public var pluralizationRules: [PluralizationRule]?
}

extension TranslationUnit: Equatable {
    static public func ==(lhs: TranslationUnit, rhs: TranslationUnit) -> Bool {
        return lhs.id == rhs.id &&
            lhs.source == rhs.source &&
            lhs.target == rhs.target &&
            lhs.files == rhs.files &&
            lhs.note == rhs.note &&
            lhs.pluralizationRules == rhs.pluralizationRules
    }
}

extension TranslationUnit {
    /// If the current `TranslationUnit` contains a number of `PluralizationRule` objects in its
    /// property, then the method attempts to generate an ICU rule out of them that can be pushed to CDS.
    ///
    /// - Returns: The ICU pluralization rule if its generation is possible, nil otherwise.
    public func generateICURuleIfPossible() -> String? {
        guard let pluralizationRules = pluralizationRules,
              pluralizationRules.count > 0 else {
            return nil
        }
        
        var icuRules : [String] = []
        
        for pluralizationRule in pluralizationRules {
            if pluralizationRule.containsLocalizedFormatKey {
                continue
            }
            
            guard let pluralRule = pluralizationRule.pluralRule else {
                continue
            }
            
            guard let target = pluralizationRule.target else {
                continue
            }
            
            icuRules.append("\(pluralRule) {\(target)}")
        }
        
        guard icuRules.count > 0 else {
            return nil
        }
        
        return "{cnt, plural, \(icuRules.joined(separator: " "))}"
    }
}

/// Parses the provided XLIFF file as an XML and generates a list of translation units.
public class XLIFFParser: NSObject {
    /// The parsed translation units.
    /// If parse() hasn't been called, it returns an empty array.
    public private(set) var results: [TranslationUnit] = []

    /// Internal constants and variables used during XML parsing
    private static let XML_TRANSUNIT_NAME = "trans-unit"
    private static let XML_SOURCE_NAME = "source"
    private static let XML_TARGET_NAME = "target"
    private static let XML_NOTE_NAME = "note"
    private static let XML_FILE_NAME = "file"
    private static let XML_ID_ATTRIBUTE = "id"
    private static let XML_ORIGINAL_ATTRIBUTE = "original"
    
    private var activeTranslationUnit: PendingTranslationUnit?
    private var activeElement: String?
    private var activeFile: String?
    private var parseError: Error?
    
    private var parsesStringDict = false
    private var activePluralizationRule: PluralizationRule?
    
    /// Internal struct that's used as a temporary data structure by the XML parser to store optional fields
    /// as they are populated. This struct is then used to populate the public TranslationUnit struct.
    private struct PendingTranslationUnit {
        var id: String
        var source: String?
        var target: String?
        var note: String?
        var file: String?
        var pluralizationRules: [PluralizationRule] = []
        
        mutating func updateSource(_ inSource: String) {
            source = (source ?? "") + inSource
        }
        
        mutating func updateTarget(_ inTarget: String) {
            target = (target ?? "") + inTarget
        }
        
        mutating func updateNote(_ inNote: String) {
            note = (note ?? "") + inNote
        }
    }
    
    /// The underlying XML parser
    private var parser: XMLParser
    
    private let logHandler: TXLogHandler?
    
    /// Initializes the parser for a certain XLIFF file.
    ///
    /// If the file cannot be found, the constructor returns a nil object.
    ///
    /// You can find a sample of an XLIFF file below:
    ///
    /// ```
    /// <?xml version="1.0" encoding="UTF-8"?>
    /// <xliff xmlns="urn:oasis:names:tc:xliff:document:1.2" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="1.2" xsi:schemaLocation="urn:oasis:names:tc:xliff:document:1.2 http://docs.oasis-open.org/xliff/v1.2/os/xliff-core-1.2-strict.xsd">
    ///   <file original="project/Base.lproj/Main.storyboard" source-language="en" target-language="en" datatype="plaintext">
    ///     <header>
    ///       <tool tool-id="com.apple.dt.xcode" tool-name="Xcode" tool-version="12.0" build-num="12A7208"/>
    ///     </header>
    ///     <body>
    ///       <trans-unit id="7pN-ag-DRB.text" xml:space="preserve">
    ///         <source>Label</source>
    ///         <target>A localized label</target>
    ///         <note>Class = "UILabel"; text = "Label"; ObjectID = "7pN-ag-DRB"; Note = "The main label of the app";</note>
    ///       </trans-unit>
    ///     </body>
    ///   </file>
    ///   <file original="project/en.lproj/Localizable.strings" source-language="en" target-language="en" datatype="plaintext">
    ///     <header>
    ///       <tool tool-id="com.apple.dt.xcode" tool-name="Xcode" tool-version="12.0" build-num="12A7208"/>
    ///     </header>
    ///     <body>
    ///       <trans-unit id="This is a subtitle" xml:space="preserve">
    ///         <source>This is a subtitle</source>
    ///         <target>This is a subtitle</target>
    ///         <note>The subtitle label set programatically</note>
    ///       </trans-unit>
    ///     </body>
    ///   </file>
    /// </xliff>
    /// ```
    ///
    /// - Parameters:
    ///   - fileURL: The url of the XLIFF file
    ///   - logHandler: Optional log handler
    public init?(fileURL: URL,
                 logHandler: TXLogHandler? = nil) {
        self.logHandler = logHandler
        
        logHandler?.verbose("[prompt]Initializing XLIFF parser for[end] [file]\(fileURL.path)[end][prompt]...[end]")
        
        guard let parser = XMLParser(contentsOf: fileURL) else {
            logHandler?.error("Error reading file for parsing: \(fileURL.path)")
            return nil
        }
        
        self.parser = parser
        
        super.init()
        
        parser.delegate = self
    }
    
    /// Performs the XLIFF parsing, populating the results array with the parsed translation units.
    ///
    /// - Returns: True if the parsing was successful, false otherwise
    public func parse() -> Bool {
        logHandler?.verbose("[prompt]Parsing XLIFF...[end]")
        
        if !parser.parse() {
            logHandler?.error("Error parsing file")
            return false
        }
        
        if let parseError = parseError {
            logHandler?.error("Error while parsing: \(parseError)")
            return false
        }
        
        return true
    }

    /// List of string filenames that Transifex SDK does not support.
    public static let UNSUPPORTED_FILES = [
        "InfoPlist.strings",
        "Root.strings"
    ]

    /// Filters results by excluding translation units that their `files` array lists filenames that are included
    /// in the provided `excludeFilenames` array.
    ///
    /// If the `files` array includes a filename that is not part of the provided array, then that translation
    /// unit is not filtered out.
    ///
    /// Ref: https://transifex.github.io/transifex-swift/#special-cases
    ///
    /// - Parameter results: The parser results.
    /// - Parameter excludeFilenames: List of filenames that their translation units must be
    /// excluded.
    /// - Parameter logHandler: Optional log handler for logging purposes.
    /// - Returns: Array of filtered results that do not contain translation units that are included in the
    /// `SKIP_FILENAMES` files.
    public static func filter(_ results: [TranslationUnit],
                              excludeFilenames: [String],
                              logHandler: TXLogHandler? = nil) -> [TranslationUnit] {
        return results.filter { translationUnit in
            var excludedFilenameCount = 0
            for file in translationUnit.files {
                for excludeFilename in excludeFilenames {
                    if file.contains(excludeFilename) {
                        excludedFilenameCount += 1
                    }
                }
            }
            let isIncluded = excludedFilenameCount != translationUnit.files.count
            if let logHandler = logHandler, !isIncluded {
                logHandler.verbose("""
[prompt]Excluding \(translationUnit) due to --excluded-files argument.[end]
""")
            }
            return isIncluded
        }
    }

    /// Consolidates results based on their ID and combines their properties if needed.
    ///
    /// Call this method after parse() call was successful.
    ///
    /// - Parameter results: An array of `TranslationUnit` structs, after being parsed.
    /// - Returns: The consolidated results of the XLIFF parsing.
    public static func consolidate(_ results: [TranslationUnit]) -> [TranslationUnit] {
        guard results.count > 0 else {
            return []
        }
        
        /// Collapse exact duplicates, combine results that have the same key if possible and return
        /// any results that have the same key but couldn't be combined.
        var groupedResults: [String:[TranslationUnit]] = [:]
        
        for result in results {
            if groupedResults[result.id] == nil {
                groupedResults[result.id] = []
            }
            
            groupedResults[result.id]?.append(result)
        }
        
        var consolidatedResults : [TranslationUnit] = []
        
        for (resultID, results) in groupedResults {
            guard let firstResult = results.first else {
                continue
            }
            
            guard results.count > 1 else {
                consolidatedResults.append(firstResult)
                continue
            }
            
            var areDuplicates = true
            var note = firstResult.note
            var pluralizationRules = firstResult.pluralizationRules

            for result in results[1...] {
                if result.id != firstResult.id
                    || result.source != firstResult.source
                    || result.target != firstResult.target {
                    areDuplicates = false
                }
                
                if note == nil && result.note != nil {
                    note = result.note
                }
                
               if pluralizationRules == nil && result.pluralizationRules != nil {
                    pluralizationRules = result.pluralizationRules
                }
            }
            
            // If for some reason those units don't have the same id, source
            // or target, add them to the consolidated results as they are and
            // let the CDS decide.
            if !areDuplicates {
                consolidatedResults.append(contentsOf: results)
                continue
            }

            let files = results.compactMap({ (translationUnit) -> String in
                // Files array is quaranteed to have one element at this point
                translationUnit.files.first!
            })

            consolidatedResults.append(TranslationUnit(id: resultID,
                                                       source: firstResult.source,
                                                       target: firstResult.target,
                                                       files: files,
                                                       note: note,
                                                       pluralizationRules: pluralizationRules))
        }
        
        return consolidatedResults
    }
    
    private func appendActivePluralizationRuleToTranslationUnit() {
        guard let activePluralizationRule = activePluralizationRule else {
            return
        }
        
        activeTranslationUnit?.pluralizationRules.append(activePluralizationRule)
    }
    
    private func appendTranslationUnitToResults() {
        guard let activeTranslationUnit = activeTranslationUnit,
              let file = activeFile,
              let source = activeTranslationUnit.source,
              let target = activeTranslationUnit.target else {
            return
        }
        
        var pluralizationRules : [PluralizationRule]? = nil
        
        if activeTranslationUnit.pluralizationRules.count > 0 {
            pluralizationRules = activeTranslationUnit.pluralizationRules
        }
        
        let translationUnit = TranslationUnit(id: activeTranslationUnit.id,
                                              source: source,
                                              target: target,
                                              files: [file],
                                              note: activeTranslationUnit.note,
                                              pluralizationRules: pluralizationRules)
        
        results.append(translationUnit)
    }
}

extension XLIFFParser : XMLParserDelegate {
    public func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:]) {
        if elementName == XLIFFParser.XML_TRANSUNIT_NAME,
           let id = attributeDict[XLIFFParser.XML_ID_ATTRIBUTE] {
            
            if parsesStringDict,
               let pluralizationRule = PluralizationRule(with: id) {
                
                var shouldCreateTranslationUnit = false
                
                if let activePluralizationRule = activePluralizationRule,
                   !activePluralizationRule.hasSameSourceString(with: pluralizationRule) {
                    shouldCreateTranslationUnit = true
                }
                else if activeTranslationUnit == nil {
                    shouldCreateTranslationUnit = true
                }
                
                if activePluralizationRule != nil
                   && activeTranslationUnit != nil {
                    appendActivePluralizationRuleToTranslationUnit()
                }
                
                if activeTranslationUnit != nil
                   && shouldCreateTranslationUnit {
                    appendTranslationUnitToResults()
                }
                
                activePluralizationRule = pluralizationRule
                
                if shouldCreateTranslationUnit {
                    activeTranslationUnit = PendingTranslationUnit(id: pluralizationRule.sourceString,
                                                                   source: pluralizationRule.sourceString,
                                                                   target: pluralizationRule.sourceString)
                }
            }
            else {
                activeTranslationUnit = PendingTranslationUnit(id: id)
            }
        }
        else if elementName == XLIFFParser.XML_SOURCE_NAME
                || elementName == XLIFFParser.XML_TARGET_NAME
                || elementName == XLIFFParser.XML_NOTE_NAME {
            if activeTranslationUnit != nil {
                activeElement = elementName
            }
        }
        else if elementName == XLIFFParser.XML_FILE_NAME,
             let original = attributeDict[XLIFFParser.XML_ORIGINAL_ATTRIBUTE]{
            activeFile = original

            let fileURL = URL(fileURLWithPath: original)
            
            if fileURL.pathExtension == "stringsdict" {
                parsesStringDict = true
            }
        }
    }
    
    public func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == XLIFFParser.XML_TRANSUNIT_NAME
           && !parsesStringDict {
            appendTranslationUnitToResults()
            activeTranslationUnit = nil
        }
        else if elementName == XLIFFParser.XML_SOURCE_NAME
                || elementName == XLIFFParser.XML_TARGET_NAME
                || elementName == XLIFFParser.XML_NOTE_NAME {
            if activeTranslationUnit != nil {
                activeElement = nil
            }
        }
        else if elementName == XLIFFParser.XML_FILE_NAME {
            if parsesStringDict {
                appendActivePluralizationRuleToTranslationUnit()
                appendTranslationUnitToResults()
                
                activeTranslationUnit = nil
                activePluralizationRule = nil
                parsesStringDict = false
            }

            activeFile = nil
        }
    }
    
    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        if activeElement == XLIFFParser.XML_SOURCE_NAME {
            if activePluralizationRule != nil {
                activePluralizationRule?.updateSource(string)
            }
            else {
                activeTranslationUnit?.updateSource(string)
            }
        }
        else if activeElement == XLIFFParser.XML_TARGET_NAME {
            if activePluralizationRule != nil {
                activePluralizationRule?.updateTarget(string)
            }
            else {
                activeTranslationUnit?.updateTarget(string)
            }
        }
        else if activeElement == XLIFFParser.XML_NOTE_NAME {
            if activePluralizationRule != nil {
                activePluralizationRule?.updateNote(string)
            }
            else {
                activeTranslationUnit?.updateNote(string)
            }
        }
    }
    
    public func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError
    }
}
