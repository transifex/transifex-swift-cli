//
//  XLIFFParser.swift
//  TXCli
//
//  Created by Stelios Petrakis on 27/11/20.
//  Copyright © 2020 Transifex. All rights reserved.
//

import Foundation

/// Structure that holds all the information for the translation units from a parsed XLIFF file.
public struct TranslationUnit {
    public var id: String
    public var source: String
    public var target: String
    public var file: String
    public var note: String?
}

extension TranslationUnit: Equatable {
    static public func ==(lhs: TranslationUnit, rhs: TranslationUnit) -> Bool {
        let areEqual = lhs.id == rhs.id &&
            lhs.source == rhs.source &&
            lhs.target == rhs.target &&
            lhs.file == rhs.file &&
            lhs.note == rhs.note

        return areEqual
    }
}

/// Parses the provided XLIFF file as an XML and generates a list of translation units.
public class XLIFFParser: NSObject {
    /// The parsed translation units.
    /// If parse() hasn't been called, it returns an empty array.
    public private(set) var results: [TranslationUnit] = []

    /// Internal constants and variables used during XML parsing
    fileprivate static let XML_TRANSUNIT_NAME = "trans-unit"
    fileprivate static let XML_SOURCE_NAME = "source"
    fileprivate static let XML_TARGET_NAME = "target"
    fileprivate static let XML_NOTE_NAME = "note"
    fileprivate static let XML_FILE_NAME = "file"
    fileprivate static let XML_ID_ATTRIBUTE = "id"
    fileprivate static let XML_ORIGINAL_ATTRIBUTE = "original"
    
    fileprivate var activeTranslationUnit: PendingTranslationUnit?
    fileprivate var activeElement: String?
    fileprivate var activeFile: String?
    fileprivate var parseError: Error?
    
    /// Internal struct that's used as a temporary data structure by the XML parser to store optional fields
    /// as they are populated. This struct is then used to populate the public TranslationUnit struct.
    fileprivate struct PendingTranslationUnit {
        var id: String
        var source: String?
        var target: String?
        var note: String?
        var file: String?
    }
    
    /// The underlying XML parser
    private var parser: XMLParser
    
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
    public init?(fileURL: URL) {
        TXLogger.log("Initializing XLIFF parser for \(fileURL.path)...")
        
        guard let parser = XMLParser(contentsOf: fileURL) else {
            TXLogger.log("Error reading file for parsing: \(fileURL.path)")
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
        TXLogger.log("Parsing XLIFF...")
        
        if !parser.parse() {
            TXLogger.log("Error parsing file")
            return false
        }
        
        if let parseError = parseError {
            TXLogger.log("Error while parsing: \(parseError)")
            return false
        }
        
        return true
    }
}

extension XLIFFParser : XMLParserDelegate {
    public func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:]) {
        if elementName == XLIFFParser.XML_TRANSUNIT_NAME,
           let id = attributeDict[XLIFFParser.XML_ID_ATTRIBUTE] {
            activeTranslationUnit = PendingTranslationUnit(id: id)
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
        }
    }
    
    public func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == XLIFFParser.XML_TRANSUNIT_NAME {
            if let file = activeFile,
               let activeTranslationUnit = activeTranslationUnit,
               let source = activeTranslationUnit.source,
               let target = activeTranslationUnit.target {
                let translatioUnit = TranslationUnit(id: activeTranslationUnit.id,
                                                     source: source,
                                                     target: target,
                                                     file: file,
                                                     note: activeTranslationUnit.note)
                results.append(translatioUnit)
            }
            
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
            activeFile = nil
        }
    }
    
    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        if activeElement == XLIFFParser.XML_SOURCE_NAME {
            activeTranslationUnit?.source = string
        }
        else if activeElement == XLIFFParser.XML_TARGET_NAME {
            activeTranslationUnit?.target = string
        }
        else if activeElement == XLIFFParser.XML_NOTE_NAME {
            activeTranslationUnit?.note = string
        }
    }
    
    public func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError
    }
}
