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
                                             note: "Class = \"UILabel\"; text = \"Label\"; ObjectID = \"7pN-ag-DRB\"; Note = \"The main label of the app\";")
        
        XCTAssertEqual(results[0], translationOne)
        
        let translationTwo = TranslationUnit(id: "This is a subtitle",
                                             source: "This is a subtitle",
                                             target: "This is a subtitle",
                                             files: ["project/en.lproj/Localizable.strings"],
                                             note: "The subtitle label set programatically")
        
        XCTAssertEqual(results[1], translationTwo)
    }
    
    func testXLIFFParserWithStringsDict() {
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

        let pluralizationRules = results.first!.pluralizationRules
        
        XCTAssertTrue(pluralizationRules?.count == 3)
        
        let icuRule = results.first!.generateICURuleIfPossible()
        let expectedIcuRule = "{cnt, plural, one { %d minute } other { %d minutes }}"
        
        XCTAssertEqual(icuRule, expectedIcuRule)
    }
    
    func testXLIFFResultConsolidation() {
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
        
        XCTAssertNotNil(result.pluralizationRules)
        
        XCTAssertTrue(result.pluralizationRules!.count == 3)

        let icuRule = result.generateICURuleIfPossible()
        let expectedIcuRule = "{cnt, plural, one { %d minute } other { %d minutes }}"
        
        XCTAssertEqual(icuRule, expectedIcuRule)
    }
    
    static var allTests = [
        ("testXLIFFParser", testXLIFFParser),
        ("testXLIFFParserWithStringsDict", testXLIFFParserWithStringsDict),
        ("testXLIFFResultConsolidation", testXLIFFResultConsolidation),
    ]
}
