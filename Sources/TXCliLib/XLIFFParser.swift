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
    private static let STRINGSDICT_SEPARATOR = "/"
    private static let STRINGSDICT_DICT_TYPE = ":dict"
    private static let STRINGSDICT_STRING_TYPE = ":string"
    private static let STRINGSDICT_LOCALIZED_FORMAT_KEY = "NSStringLocalizedFormatKey"

    private static let XCSTRINGS_SEPARATOR = "|==|"

    public enum StringsSourceType {
        case StringsDict
        case XCStrings
    }

    private var components: [String]
    
    var sourceString: String
    var pluralKey: String?
    var pluralRule: String?
    var containsLocalizedFormatKey: Bool

    var source: String?
    var target: String?
    var note: String?

    var stringsSourceType : StringsSourceType

    /// Initializes the structure with the id attribute found in the `trans-unit` XML tag of the XLIFF
    /// file.
    ///
    /// From this id, the components are extracted (via the `extractComponentsXCStrings` or
    /// `extractComponentsStringsDict` static methods) and the properties are initialized:
    ///
    /// For example, if the id is the following (from a `.xcstrings` file):
    /// ```
    /// "unit-time.%d-minute(s)|==|plural.one"
    /// ```
    ///
    /// Then the properties have the following values:
    /// sourceString: "unit-time.%d-minute(s)"
    /// pluralKey: nil
    /// pluralRule: "plural.one"
    /// containsLocalizedFormatKey: false
    ///
    /// On the other hand, if the id is the following (from a `.stringsdict` file):
    /// ```
    /// "/unit-time.%d-minute(s):dict/d_unit_time:dict/one:dict/:string"
    /// ```
    ///
    /// Then the properties have the following values:
    /// sourceString: "unit-time.%d-minute(s)"
    /// pluralKey: "d_unit_time"
    /// pluralRule: "one"
    /// containsLocalizedFormatKey: false
    ///
    /// - Parameter id: The id attribute
    init?(with id: String) {
        if Self.isXCStringsID(id) {
            self.stringsSourceType = .XCStrings

            // Modern .xcstrings format
            let components = Self.extractComponentsXCStrings(from: id)

            if components.count != 2 {
                return nil
            }

            self.components = components
            self.sourceString = components[0]
            self.containsLocalizedFormatKey = false
            self.pluralKey = nil
            self.pluralRule = components[1]
        }
        else {
            self.stringsSourceType = .StringsDict

            // Legacy .stringsdict format
            let components = Self.extractComponentsStringsDict(from: id)

            if components.count < 2 {
                return nil
            }

            self.components = components
            self.sourceString = components[0]
            self.containsLocalizedFormatKey = id.contains(Self.STRINGSDICT_LOCALIZED_FORMAT_KEY)

            if self.containsLocalizedFormatKey {
                return
            }

            self.pluralKey = components[1]

            if self.components.count > 2 {
                self.pluralRule = self.components[2]
            }
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
    static private func extractComponentsStringsDict(from id: String) -> [String] {
        return id
            .replacingOccurrences(of: Self.STRINGSDICT_DICT_TYPE, with: "")
            .replacingOccurrences(of: Self.STRINGSDICT_STRING_TYPE, with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: Self.STRINGSDICT_SEPARATOR))
            .components(separatedBy: Self.STRINGSDICT_SEPARATOR)
    }

    /// Parses the id attribute of the `trans-unit` XML tag and splits the string into components that
    /// each represents a certain property to be used during the initialization of the `PluralizationRule`
    ///
    /// e.g:
    /// For id:
    /// "unit-time.%d-minute(s)|==|plural.one"
    /// The components returned are:
    /// [ "unit-time.%d-minute(s)", "plural.one"]
    ///
    /// - Parameter id: The id attribute
    /// - Returns: The components that define this pluralization rule
    static private func extractComponentsXCStrings(from id: String) -> [String] {
        return id.components(separatedBy: XCSTRINGS_SEPARATOR)
    }

    /// - Parameter id: The id attribute
    /// - Returns: True if the id contains a XCString identifier, False otherwise
    static private func isXCStringsID(_ id: String) -> Bool {
        return id.contains(XCSTRINGS_SEPARATOR)
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
    public var pluralizationRules: [PluralizationRule]
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
    /// Tags used by Apple's .xcstrings format
    private static let XCSTRINGS_PLURAL_RULE_PREFIX = "plural"
    private static let XCSTRINGS_DEVICE_RULE_PREFIX = "device"
    private static let XCSTRINGS_SUBSTITUTIONS_RULE_PREFIX = "substitutions"

    /// The types of the generated ICU rule by the `generateICURuleIfPossible` method.
    public enum ICURuleType {
        // Pluralization (Simple plural rule, supported by CDS in ICU format)
        case Plural
        // Vary by device (Converted to XML for CDS)
        case Device
        // Substitution (multiple variables) (Converted to XML for CDS)
        case Substitutions
        // Unexpected/empty rule encountered
        case Other
    }
    
    /// All possible errors emitted by the `generateICURuleIfPossible` method.
    public enum ICUError: Error, CustomDebugStringConvertible {
        // Not supported
        case notSupported(ICURuleType)
        // No pluralization rules found to process. Not really an error.
        case noRules
        // The legacy pluralization rules (.stringsdict) contain a localized
        // format key that is not on the format that Apple recommends.
        case malformedPluralizedFormat(String)
        // The method could not generate an ICU rule based on the provided
        // pluralization rules.
        case emptyRule

        public var debugDescription: String {
            switch (self) {
            case .notSupported(let type):
                return "Pluralization rule not supported: \(type)"
            case .noRules:
                return "No pluralization rules found"
            case .malformedPluralizedFormat(let error):
                return "Malformed pluralized format detected: \(error)"
            case .emptyRule:
                return "Unable to generate ICU rule"
            }
        }
    }

    /// If the current `TranslationUnit` contains a number of `PluralizationRule` objects in its
    /// property, then the method attempts to generate an ICU rule out of them that can be pushed to CDS
    /// either as a single ICU rule or as an intermediate XML structure.
    ///
    /// - Returns: The ICU pluralization rule if its generation is possible, nil otherwise.
    public func generateICURuleIfPossible() -> Result<(String, ICURuleType), ICUError> {
        guard pluralizationRules.count > 0 else {
            return .failure(.noRules)
        }

        guard let activeStringsSourceType = pluralizationRules.map({ $0.stringsSourceType }).first else {
            return .failure(.noRules)
        }

        var icuRuleType: ICURuleType = .Other

        if activeStringsSourceType == .StringsDict {
            // For the legacy .stringsdict format, if the localized format key
            // contains more than two tokens, then it means that it contains
            // substitutions. In this case we want to convert it to XML just
            // like we do with .xcstrings substitutions.
            //
            // As per documentation:
            // > If the formatted string contains multiple variables, enter a
            // > separate subdictionary for each variable.
            //
            // Ref: https://developer.apple.com/documentation/xcode/localizing-strings-that-contain-plurals
            if let target = pluralizationRules.filter({ $0.containsLocalizedFormatKey}).first?.target {
                let tokenCount = PluralUtils.extractTokens(from: target).count
                if tokenCount > 1 {
                    icuRuleType = .Substitutions
                }
                else if tokenCount == 1 {
                    icuRuleType = .Plural
                }
            }
        }
        else {
            // Simple plural .xcstrings rules can be converted to a single ICU
            // rule
            if let pluralRule = pluralizationRules.first?.pluralRule,
               pluralRule.starts(with: "\(Self.XCSTRINGS_PLURAL_RULE_PREFIX).") {
                icuRuleType = .Plural
            }
            else {
                if let rule = pluralizationRules.first?.pluralRule?.components(separatedBy: ".").first {
                    switch rule {
                    case Self.XCSTRINGS_DEVICE_RULE_PREFIX:
                        icuRuleType = .Device
                    case Self.XCSTRINGS_SUBSTITUTIONS_RULE_PREFIX:
                        icuRuleType = .Substitutions
                    default:
                        icuRuleType = .Other
                    }
                }
            }
        }

        guard icuRuleType != .Other else {
            return .failure(.notSupported(.Other))
        }

        var cdsRule: String? = nil

        if icuRuleType == .Plural {
            // Single ICU rules are supported by CDS, so convert it and send it
            // like that.
            cdsRule = generateSingleICURule(pluralizationRules)
        }
        else {
            // Otherwise convert all the plural rules to XML so that the CDS web
            // UI can render them and then process them in the SDK when fetched.
            cdsRule = generateXMLRule(pluralizationRules,
                                      type: activeStringsSourceType)
        }

        guard let cdsRule = cdsRule else {
            return .failure(.emptyRule)
        }

        return .success((cdsRule, icuRuleType))
    }

    /// For simple plural variations that just contain one plural rule which covers the whole phrase, we
    /// generate the ICU rule in the format that is accepted by CDS.
    ///
    /// - Parameter pluralizationRules: The pluralization rules that make up the plural variation
    /// - Returns: The generated ICU rule as a String, nil in case of an error (if no pluralization rules
    /// could be processed).
    private func generateSingleICURule(_ pluralizationRules: [PluralizationRule]) -> String? {
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

            let normalizedRule = pluralRule.replacingOccurrences(of: "\(Self.XCSTRINGS_PLURAL_RULE_PREFIX).",
                                                                 with: "")
            icuRules.append("\(normalizedRule) {\(target)}")
        }

        guard icuRules.count > 0 else {
            return nil
        }

        return "{cnt, plural, \(icuRules.joined(separator: " "))}"
    }

    /// For any complex variations (device, multiple plurals, tokens and their combinations), we generate
    /// an intermediate XML structure that will be rendered in the Transifex web interface accordingly and
    /// then processed by the SDK when pulled.
    ///
    /// - Parameters:
    ///   - pluralizationRules: The pluralization rules that make up the complex variation.
    ///   - type: The type governing the pluralization rules
    /// - Returns: The generated XML structure as a String, nil in case of an error (if no XML children
    /// could be generated).
    private func generateXMLRule(_ pluralizationRules: [PluralizationRule],
                                 type: PluralizationRule.StringsSourceType) -> String? {
        switch type {
        case .XCStrings:
            let root = XMLElement(name: TXNative.CDS_XML_ROOT_TAG_NAME)

            // Used for substitutions where the first trans-unit contains the
            // phrase.
            // e.g.
            // ```
            // <trans-unit id="substitutions_key" xml:space="preserve">
            //   <source>Found %1$#@arg1@ having %2$#@arg2@</source>
            //   <target state="translated">Found %1$#@arg1@ having %2$#@arg2@</target>
            //   <note/>
            // </trans-unit>
            // <trans-unit id="substitutions_key|==|substitutions.arg1.plural.one" xml:space="preserve">
            //   <source>%1$ld user</source>
            //   <target state="translated">%1$ld user</target>
            //   <note/>
            // </trans-unit>
            // ...
            // ```
            if target != id {
                if let attribute = XMLNode.attribute(withName: TXNative.CDS_XML_ID_ATTRIBUTE,
                                                     stringValue: Self.XCSTRINGS_SUBSTITUTIONS_RULE_PREFIX) as? XMLNode {
                    let xmlElement = XMLElement(name: TXNative.CDS_XML_TAG_NAME,
                                                stringValue: target)
                    xmlElement.addAttribute(attribute)
                    root.addChild(xmlElement)
                }
            }
            
            for pluralizationRule in pluralizationRules {
                guard let pluralRule = pluralizationRule.pluralRule else {
                    continue
                }

                guard let target = pluralizationRule.target else {
                    continue
                }

                if let attribute = XMLNode.attribute(withName: TXNative.CDS_XML_ID_ATTRIBUTE,
                                                     stringValue: pluralRule) as? XMLNode {
                    let xmlElement = XMLElement(name: TXNative.CDS_XML_TAG_NAME,
                                                stringValue: target)
                    xmlElement.addAttribute(attribute)
                    root.addChild(xmlElement)
                }
            }
            
            return root.childCount > 0 ? root.xmlString : nil
        case .StringsDict:
            // For the legacy substitutions, we attempt to convert the XML tags
            // to the format of the `.xcstrings` above, so that the SDK can
            // parse both of them, regardless of their initial type.
            //
            // This means that the pluralization rule that contains the localized
            // format key (.containsLocalizedFormatKey == true), will become the
            // main substitutions phrase, and have an id of "substitutions".
            // Each of the other rules, will have an id that follows the format:
            // "substitutions.PLURAL_KEY.plural.PLURAL_RULE".
            let root = XMLElement(name: TXNative.CDS_XML_ROOT_TAG_NAME)

            for pluralizationRule in pluralizationRules {
                guard let target = pluralizationRule.target else {
                    continue
                }

                if pluralizationRule.containsLocalizedFormatKey {
                    if let attribute = XMLNode.attribute(withName: TXNative.CDS_XML_ID_ATTRIBUTE,
                                                         stringValue: Self.XCSTRINGS_SUBSTITUTIONS_RULE_PREFIX) as? XMLNode {
                        let xmlElement = XMLElement(name: TXNative.CDS_XML_TAG_NAME,
                                                    stringValue: target)
                        xmlElement.addAttribute(attribute)
                        root.addChild(xmlElement)
                    }
                    continue
                }

                guard let pluralRule = pluralizationRule.pluralRule,
                      let pluralKey = pluralizationRule.pluralKey else {
                    continue
                }

                let id = "\(Self.XCSTRINGS_SUBSTITUTIONS_RULE_PREFIX).\(pluralKey).\(Self.XCSTRINGS_PLURAL_RULE_PREFIX).\(pluralRule)"
                if let attribute = XMLNode.attribute(withName: TXNative.CDS_XML_ID_ATTRIBUTE,
                                                     stringValue: id) as? XMLNode {
                    let xmlElement = XMLElement(name: TXNative.CDS_XML_TAG_NAME,
                                                stringValue: target)
                    xmlElement.addAttribute(attribute)
                    root.addChild(xmlElement)
                }
            }

            return root.childCount > 0 ? root.xmlString : nil
        }
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

    private var pendingTranslationUnits: [PendingTranslationUnit] = []
    private var pendingPluralizationRules: [PluralizationRule] = []

    private var activeTranslationUnit: PendingTranslationUnit?
    private var activeElementName: String?
    private var activeFileName: String?
    private var parseError: Error?
    
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
                
                pluralizationRules = result.pluralizationRules
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

    /// Adds pending translation units and pluralization rules to the results array.
    private func processPendingStructures() {
        guard let fileName = activeFileName else {
            return
        }

        // Process the translation units first
        for pendingTranslationUnit in pendingTranslationUnits {
            guard let source = pendingTranslationUnit.source,
                  let target = pendingTranslationUnit.target else {
                continue
            }

            let id = pendingTranslationUnit.id

            // Find the associated pluralization rules for this translation
            // unit.
            let pluralizationRules = pendingPluralizationRules.filter {
                $0.sourceString == id
            }

            let translationUnit = TranslationUnit(id: pendingTranslationUnit.id,
                                                  source: source,
                                                  target: target,
                                                  files: [fileName],
                                                  note: pendingTranslationUnit.note,
                                                  pluralizationRules: pluralizationRules)
            results.append(translationUnit)

            // Remove the found rules from the pending array.
            pendingPluralizationRules.removeAll { $0.sourceString == id }
        }

        pendingTranslationUnits.removeAll()

        // If there are leftover pending pluralization rules, it means that they
        // do not have an associated translation unit.
        if pendingPluralizationRules.count > 0 {
            // Group them based on their source string (use Set to use only the
            // unique source strings).
            let sourceStrings = Set(pendingPluralizationRules.map {
                $0.sourceString
            }).sorted()

            // Process each group.
            for sourceString in sourceStrings {
                let pluralizationRules = pendingPluralizationRules.filter {
                    $0.sourceString == sourceString
                }

                if pluralizationRules.count == 0 {
                    continue
                }

                // Create a translation unit that hosts those rules.
                let translationUnit = TranslationUnit(id: sourceString,
                                                      source: sourceString,
                                                      target: sourceString,
                                                      files: [fileName],
                                                      note: nil,
                                                      pluralizationRules: pluralizationRules)
                results.append(translationUnit)
            }
        }

        pendingPluralizationRules.removeAll()
    }
}

extension XLIFFParser : XMLParserDelegate {
    public func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:]) {
        // <trans-unit id="{SOMETHING}">
        if elementName == Self.XML_TRANSUNIT_NAME,
           let id = attributeDict[Self.XML_ID_ATTRIBUTE] {

            if let pluralizationRule = PluralizationRule(with: id) {
                activePluralizationRule = pluralizationRule
            }
            else {
                activeTranslationUnit = PendingTranslationUnit(id: id)
            }
        }
        // <source>, <target>, <note>
        else if elementName == Self.XML_SOURCE_NAME
                    || elementName == Self.XML_TARGET_NAME
                    || elementName == Self.XML_NOTE_NAME {
            activeElementName = elementName
        }
        // <file original="{SOMETHING}">
        else if elementName == Self.XML_FILE_NAME,
                let original = attributeDict[Self.XML_ORIGINAL_ATTRIBUTE]{
            activeFileName = original
        }
    }
    
    public func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        // </trans-unit>
        if elementName == Self.XML_TRANSUNIT_NAME {
            // If the translation unit contained a pluralization rule, append
            // it to the active translation unit.
            if let activePluralizationRule = activePluralizationRule {
                pendingPluralizationRules.append(activePluralizationRule)
                self.activePluralizationRule = nil
            }
            else if let activeTranslationUnit = activeTranslationUnit {
                pendingTranslationUnits.append(activeTranslationUnit)
                self.activeTranslationUnit = nil
            }
        }
        // </source>, </target>, </note>
        else if elementName == Self.XML_SOURCE_NAME
                    || elementName == Self.XML_TARGET_NAME
                    || elementName == Self.XML_NOTE_NAME {
            activeElementName = nil
        }
        // </file>
        else if elementName == Self.XML_FILE_NAME {
            processPendingStructures()
            activeFileName = nil
        }
    }
    
    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        // <source>{SOMETHING}</source>
        if activeElementName == Self.XML_SOURCE_NAME {
            if activePluralizationRule != nil {
                activePluralizationRule?.updateSource(string)
            }
            else {
                activeTranslationUnit?.updateSource(string)
            }
        }
        // <target>{SOMETHING}</target>
        else if activeElementName == Self.XML_TARGET_NAME {
            if activePluralizationRule != nil {
                activePluralizationRule?.updateTarget(string)
            }
            else {
                activeTranslationUnit?.updateTarget(string)
            }
        }
        // <note>{SOMETHING}</note>
        else if activeElementName == Self.XML_NOTE_NAME {
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
