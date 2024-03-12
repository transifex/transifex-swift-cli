import XCTest
@testable import TXCliLib

final class XLIFFParserTests: XCTestCase {
    func tempXLIFFFileURL() -> URL {
        return URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("sample.xliff")
    }
    
    override func setUp() {
        let fileURL = tempXLIFFFileURL()
        do {
            try "".write(to: fileURL, atomically: true, encoding: .utf8)
        }
        catch {}
    }
    
    override func tearDown() {
        let fileURL = tempXLIFFFileURL()
        do {
            try FileManager.default.removeItem(at: fileURL)
        }
        catch {}
    }
    
    func testXLIFFParser() {
        let fileURL = tempXLIFFFileURL()
        let sampleXLIFF = """
<?xml version="1.0" encoding="UTF-8"?>
<xliff xmlns="urn:oasis:names:tc:xliff:document:1.2" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="1.2" xsi:schemaLocation="urn:oasis:names:tc:xliff:document:1.2 http://docs.oasis-open.org/xliff/v1.2/os/xliff-core-1.2-strict.xsd">
<file original="project/Base.lproj/Main.storyboard" source-language="en" target-language="en" datatype="plaintext">
 <header>
   <tool tool-id="com.apple.dt.xcode" tool-name="Xcode" tool-version="12.0" build-num="12A7208"/>
 </header>
 <body>
   <trans-unit id="7pN-ag-DRB.text" xml:space="preserve">
     <source>Label</source>
     <target>A localized label</target>
     <note>Class = "UILabel"; text = "Label"; ObjectID = "7pN-ag-DRB"; Note = "The main label of the app";</note>
   </trans-unit>
 </body>
</file>
<file original="project/en.lproj/Localizable.strings" source-language="en" target-language="en" datatype="plaintext">
 <header>
   <tool tool-id="com.apple.dt.xcode" tool-name="Xcode" tool-version="12.0" build-num="12A7208"/>
 </header>
 <body>
   <trans-unit id="This is a subtitle" xml:space="preserve">
     <source>This is a subtitle</source>
     <target>This is a subtitle</target>
     <note>The subtitle label set programatically</note>
   </trans-unit>
 </body>
</file>
</xliff>
"""
        do {
            try sampleXLIFF.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        catch { }
        
        let xliffParser = XLIFFParser(fileURL: fileURL)
        XCTAssertNotNil(xliffParser, "Failed to initialize parser")

        let parsed = xliffParser!.parse()

        XCTAssertTrue(parsed)

        let results = xliffParser!.results

        XCTAssertTrue(results.count == 2)
        
        let translationOne = TranslationUnit(id: "7pN-ag-DRB.text",
                                             source: "Label",
                                             target: "A localized label",
                                             files: ["project/Base.lproj/Main.storyboard"],
                                             note: "Class = \"UILabel\"; text = \"Label\"; ObjectID = \"7pN-ag-DRB\"; Note = \"The main label of the app\";",
                                             pluralizationRules: [])
        
        XCTAssertEqual(results[0], translationOne)
        
        let translationTwo = TranslationUnit(id: "This is a subtitle",
                                             source: "This is a subtitle",
                                             target: "This is a subtitle",
                                             files: ["project/en.lproj/Localizable.strings"],
                                             note: "The subtitle label set programatically",
                                             pluralizationRules: [])
        
        XCTAssertEqual(results[1], translationTwo)
    }
    
    func testXLIFFParserWithXCStrings() throws {
        let fileURL = tempXLIFFFileURL()
        let sampleXLIFF = """
<?xml version="1.0" encoding="UTF-8"?>
<xliff xmlns="urn:oasis:names:tc:xliff:document:1.2" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="1.2" xsi:schemaLocation="urn:oasis:names:tc:xliff:document:1.2 http://docs.oasis-open.org/xliff/v1.2/os/xliff-core-1.2-strict.xsd">
  <file original="SwiftSampleApp/Localizable.xcstrings" source-language="en" target-language="en" datatype="plaintext">
    <header>
      <tool tool-id="com.apple.dt.xcode" tool-name="Xcode" tool-version="15.3" build-num="15E204a"/>
    </header>
    <body>
      <trans-unit id="I find your lack of faith disturbing." xml:space="preserve">
        <source>I find your lack of faith disturbing.</source>
        <target state="new">I find your lack of faith disturbing.</target>
        <note/>
      </trans-unit>
      <trans-unit id="Powerful you have become, the dark side I sense in you." xml:space="preserve">
        <source>Powerful you have become, the dark side I sense in you.</source>
        <target state="new">Powerful you have become, the dark side I sense in you.</target>
        <note/>
      </trans-unit>
      <trans-unit id="test string" xml:space="preserve">
        <source>test string</source>
        <target state="new">test string</target>
        <note>Test comment</note>
      </trans-unit>
      <trans-unit id="unit-time.%d-minute(s)|==|plural.one" xml:space="preserve">
        <source>%d minute</source>
        <target state="translated">%d minute</target>
        <note>dminutes</note>
      </trans-unit>
      <trans-unit id="unit-time.%d-minute(s)|==|plural.other" xml:space="preserve">
        <source>%d minutes</source>
        <target state="translated">%d minutes</target>
        <note>dminutes</note>
      </trans-unit>
      <trans-unit id="unit-time.%u-minute(s)|==|plural.one" xml:space="preserve">
        <source>%u minute</source>
        <target state="translated">%u minute</target>
        <note>uminutes</note>
      </trans-unit>
      <trans-unit id="unit-time.%u-minute(s)|==|plural.other" xml:space="preserve">
        <source>%u minutes</source>
        <target state="translated">%u minutes</target>
        <note>uminutes</note>
      </trans-unit>
    </body>
  </file>
</xliff>
"""
        do {
            try sampleXLIFF.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        catch { }

        let xliffParser = XLIFFParser(fileURL: fileURL)
        XCTAssertNotNil(xliffParser, "Failed to initialize parser")

        let parsed = xliffParser!.parse()

        XCTAssertTrue(parsed)

        let results = xliffParser!.results

        XCTAssertTrue(results.count == 5)

        do {
            let pluralizedResult = results[3]

            XCTAssertTrue(pluralizedResult.pluralizationRules.count == 2)

            let icuRule = try pluralizedResult.generateICURuleIfPossible().get()

            let expectedIcuRule = "{cnt, plural, one {%d minute} other {%d minutes}}"

            XCTAssertEqual(icuRule.0, expectedIcuRule)
            XCTAssertEqual(icuRule.1, .Plural)
        }

        do {
            let pluralizedResult = results[4]

            XCTAssertTrue(pluralizedResult.pluralizationRules.count == 2)

            let icuRule = try pluralizedResult.generateICURuleIfPossible().get()

            let expectedIcuRule = "{cnt, plural, one {%u minute} other {%u minutes}}"

            XCTAssertEqual(icuRule.0, expectedIcuRule)
            XCTAssertEqual(icuRule.1, .Plural)
        }
    }

    func testXLIFFParserWithStringsDict() throws {
        let fileURL = tempXLIFFFileURL()
        let sampleXLIFF = """
<?xml version="1.0" encoding="UTF-8"?>
<xliff xmlns="urn:oasis:names:tc:xliff:document:1.2" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="1.2" xsi:schemaLocation="urn:oasis:names:tc:xliff:document:1.2 http://docs.oasis-open.org/xliff/v1.2/os/xliff-core-1.2-strict.xsd">
  <file original="Localizable.stringsdict" source-language="en" target-language="en" datatype="plaintext">
    <header>
      <tool tool-id="com.apple.dt.xcode" tool-name="Xcode" tool-version="12.3" build-num="12C33"/>
    </header>
    <body>
      <trans-unit id="/unit-time.%d-minute(s):dict/NSStringLocalizedFormatKey:dict/:string" xml:space="preserve">
        <source>%#@d_unit_time@</source>
        <target>%#@d_unit_time@</target>
        <note/>
      </trans-unit>
      <trans-unit id="/unit-time.%d-minute(s):dict/d_unit_time:dict/one:dict/:string" xml:space="preserve">
        <source>%d minute</source>
        <target>%d minute</target>
        <note/>
      </trans-unit>
      <trans-unit id="/unit-time.%d-minute(s):dict/d_unit_time:dict/other:dict/:string" xml:space="preserve">
        <source>%d minutes</source>
        <target>%d minutes</target>
        <note/>
      </trans-unit>
    </body>
  </file>
</xliff>
"""
        do {
            try sampleXLIFF.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        catch { }
        
        let xliffParser = XLIFFParser(fileURL: fileURL)
        XCTAssertNotNil(xliffParser, "Failed to initialize parser")

        let parsed = xliffParser!.parse()

        XCTAssertTrue(parsed)

        let results = xliffParser!.results

        XCTAssertTrue(results.count == 1)

        XCTAssertTrue(results.first!.pluralizationRules.count == 3)
        
        let icuRule = try results.first!.generateICURuleIfPossible().get()

        let expectedIcuRule = "{cnt, plural, one {%d minute} other {%d minutes}}"

        XCTAssertEqual(icuRule.0, expectedIcuRule)
        XCTAssertEqual(icuRule.1, .Plural)
    }

    func testXLIFFResultConsolidation() throws {
        let fileURL = tempXLIFFFileURL()
        let sampleXLIFF = """
<?xml version="1.0" encoding="UTF-8"?>
<xliff xmlns="urn:oasis:names:tc:xliff:document:1.2" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="1.2" xsi:schemaLocation="urn:oasis:names:tc:xliff:document:1.2 http://docs.oasis-open.org/xliff/v1.2/os/xliff-core-1.2-strict.xsd">
  <file original="Localizable.strings" source-language="en" target-language="en" datatype="plaintext">
    <header>
      <tool tool-id="com.apple.dt.xcode" tool-name="Xcode" tool-version="12.3" build-num="12C33"/>
    </header>
    <body>
      <trans-unit id="unit-time.%d-minute(s)" xml:space="preserve">
        <source>unit-time.%d-minute(s)</source>
        <target>unit-time.%d-minute(s)</target>
        <note>dminutes</note>
      </trans-unit>
    </body>
  </file>
  <file original="Localizable.stringsdict" source-language="en" target-language="en" datatype="plaintext">
    <header>
      <tool tool-id="com.apple.dt.xcode" tool-name="Xcode" tool-version="12.3" build-num="12C33"/>
    </header>
    <body>
      <trans-unit id="/unit-time.%d-minute(s):dict/NSStringLocalizedFormatKey:dict/:string" xml:space="preserve">
        <source>%#@d_unit_time@</source>
        <target>%#@d_unit_time@</target>
        <note/>
      </trans-unit>
      <trans-unit id="/unit-time.%d-minute(s):dict/d_unit_time:dict/one:dict/:string" xml:space="preserve">
        <source>%d minute</source>
        <target>%d minute</target>
        <note/>
      </trans-unit>
      <trans-unit id="/unit-time.%d-minute(s):dict/d_unit_time:dict/other:dict/:string" xml:space="preserve">
        <source>%d minutes</source>
        <target>%d minutes</target>
        <note/>
      </trans-unit>
    </body>
  </file>
</xliff>
"""
        do {
            try sampleXLIFF.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        catch { }
        
        let xliffParser = XLIFFParser(fileURL: fileURL)
        XCTAssertNotNil(xliffParser, "Failed to initialize parser")

        let parsed = xliffParser!.parse()

        XCTAssertTrue(parsed)

        let results = xliffParser!.results

        XCTAssertTrue(results.count == 2)

        let consolidatedResults = XLIFFParser.consolidate(xliffParser!.results)
        
        XCTAssertTrue(consolidatedResults.count == 1)
        
        let result = consolidatedResults.first!
        
        XCTAssertNotNil(result.note)

        XCTAssertTrue(result.pluralizationRules.count == 3)

        let icuRule = try result.generateICURuleIfPossible().get()

        let expectedIcuRule = "{cnt, plural, one {%d minute} other {%d minutes}}"

        XCTAssertEqual(icuRule.0, expectedIcuRule)
        XCTAssertEqual(icuRule.1, .Plural)
    }
    
    func testXLIFFParserWithQuotes() {
        let fileURL = tempXLIFFFileURL()
        let sampleXLIFF = """
<?xml version="1.0" encoding="UTF-8"?>
<xliff xmlns="urn:oasis:names:tc:xliff:document:1.2" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="1.2" xsi:schemaLocation="urn:oasis:names:tc:xliff:document:1.2 http://docs.oasis-open.org/xliff/v1.2/os/xliff-core-1.2-strict.xsd">
  <file original="Localizable.strings" source-language="en" target-language="en" datatype="plaintext">
    <header>
      <tool tool-id="com.apple.dt.xcode" tool-name="Xcode" tool-version="12.3" build-num="12C33"/>
    </header>
    <body>
      <trans-unit id="vyW-d6-PC8.text" xml:space="preserve">
        <source>We’re réa`dy!</source>
        <target>We’re réa`dy!</target>
        <note>Class = "UILabel"; text = "We’re réa`dy!"; ObjectID = "vyW-d6-PC8";</note>
      </trans-unit>
    </body>
  </file>
</xliff>
"""
        do {
            try sampleXLIFF.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        catch { }
        
        let xliffParser = XLIFFParser(fileURL: fileURL)
        XCTAssertNotNil(xliffParser, "Failed to initialize parser")

        let parsed = xliffParser!.parse()

        XCTAssertTrue(parsed)

        let results = xliffParser!.results

        XCTAssertTrue(results.count == 1)

        let result = results.first!
        
        XCTAssertEqual(result.source, "We’re réa`dy!")
        
        XCTAssertEqual(result.target, "We’re réa`dy!")
    }
    
    static var allTests = [
        ("testXLIFFParser", testXLIFFParser),
        ("testXLIFFParserWithStringsDict", testXLIFFParserWithStringsDict),
        ("testXLIFFResultConsolidation", testXLIFFResultConsolidation),
        ("testXLIFFParserWithQuotes", testXLIFFParserWithQuotes),
    ]
}
