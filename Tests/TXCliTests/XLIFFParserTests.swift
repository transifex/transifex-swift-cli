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
      <trans-unit id="/old_substitution:dict/NSStringLocalizedFormatKey:dict/:string" xml:space="preserve">
        <source>%#@num_people_in_room@ in %#@room@</source>
        <target>%#@num_people_in_room@ in %#@room@</target>
        <note/>
      </trans-unit>
      <trans-unit id="/old_substitution:dict/num_people_in_room:dict/one:dict/:string" xml:space="preserve">
        <source>Only %d person</source>
        <target>Only %d person</target>
        <note/>
      </trans-unit>
      <trans-unit id="/old_substitution:dict/num_people_in_room:dict/other:dict/:string" xml:space="preserve">
        <source>Some people</source>
        <target>Some people</target>
        <note/>
      </trans-unit>
      <trans-unit id="/old_substitution:dict/num_people_in_room:dict/zero:dict/:string" xml:space="preserve">
        <source>No people</source>
        <target>No people</target>
        <note/>
      </trans-unit>
      <trans-unit id="/old_substitution:dict/room:dict/one:dict/:string" xml:space="preserve">
        <source>%d room</source>
        <target>%d room</target>
        <note/>
      </trans-unit>
      <trans-unit id="/old_substitution:dict/room:dict/other:dict/:string" xml:space="preserve">
        <source>%d rooms</source>
        <target>%d rooms</target>
        <note/>
      </trans-unit>
      <trans-unit id="/old_substitution:dict/room:dict/zero:dict/:string" xml:space="preserve">
        <source>no room</source>
        <target>no room</target>
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

        do {
            let result = results[0]
            XCTAssertEqual(result.pluralizationRules.count, 7)
            let icuRule = try result.generateICURuleIfPossible().get()
            let expectedIcuRule = "<cds-root><cds-unit id=\"substitutions\">%#@num_people_in_room@ in %#@room@</cds-unit><cds-unit id=\"substitutions.num_people_in_room.plural.one\">Only %d person</cds-unit><cds-unit id=\"substitutions.num_people_in_room.plural.other\">Some people</cds-unit><cds-unit id=\"substitutions.num_people_in_room.plural.zero\">No people</cds-unit><cds-unit id=\"substitutions.room.plural.one\">%d room</cds-unit><cds-unit id=\"substitutions.room.plural.other\">%d rooms</cds-unit><cds-unit id=\"substitutions.room.plural.zero\">no room</cds-unit></cds-root>"
            XCTAssertEqual(icuRule.0, expectedIcuRule)
            XCTAssertEqual(icuRule.1, .Substitutions)
        }

        do {
            let result = results[1]
            XCTAssertEqual(result.pluralizationRules.count, 3)
            
            let icuRule = try result.generateICURuleIfPossible().get()
            let expectedIcuRule = "{cnt, plural, one {%d minute} other {%d minutes}}"
            
            XCTAssertEqual(icuRule.0, expectedIcuRule)
            XCTAssertEqual(icuRule.1, .Plural)
        }
    }

    func testXLIFFParserWithXCStringsSubstitutions() throws {
        let fileURL = tempXLIFFFileURL()
        let sampleXLIFF = """
<?xml version="1.0" encoding="UTF-8"?>
<xliff xmlns="urn:oasis:names:tc:xliff:document:1.2" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="1.2" xsi:schemaLocation="urn:oasis:names:tc:xliff:document:1.2 http://docs.oasis-open.org/xliff/v1.2/os/xliff-core-1.2-strict.xsd">
  <file original="Localizable.stringsdict" source-language="en" target-language="en" datatype="plaintext">
    <header>
      <tool tool-id="com.apple.dt.xcode" tool-name="Xcode" tool-version="12.3" build-num="12C33"/>
    </header>
    <body>
      <trans-unit id="substitutions_test" xml:space="preserve">
        <source>Found %1$#@arg1@ having %2$#@arg2@</source>
        <target state="translated">Found %1$#@arg1@ having %2$#@arg2@</target>
        <note/>
      </trans-unit>
      <trans-unit id="substitutions_test|==|substitutions.arg1.plural.one" xml:space="preserve">
        <source>%1$ld user</source>
        <target state="translated">%1$ld user</target>
        <note/>
      </trans-unit>
      <trans-unit id="substitutions_test|==|substitutions.arg1.plural.other" xml:space="preserve">
        <source>%1$ld users</source>
        <target state="translated">%1$ld users</target>
        <note/>
      </trans-unit>
      <trans-unit id="substitutions_test|==|substitutions.arg2.plural.one" xml:space="preserve">
        <source>%2$ld device</source>
        <target state="translated">%2$ld device</target>
        <note/>
      </trans-unit>
      <trans-unit id="substitutions_test|==|substitutions.arg2.plural.other" xml:space="preserve">
        <source>%2$ld devices</source>
        <target state="translated">%2$ld devices</target>
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

        XCTAssertEqual(results.first!.pluralizationRules.count, 4)

        let icuRule = try results.first!.generateICURuleIfPossible().get()

        let expectedIcuRule = "<cds-root><cds-unit id=\"substitutions\">Found %1$#@arg1@ having %2$#@arg2@</cds-unit><cds-unit id=\"substitutions.arg1.plural.one\">%1$ld user</cds-unit><cds-unit id=\"substitutions.arg1.plural.other\">%1$ld users</cds-unit><cds-unit id=\"substitutions.arg2.plural.one\">%2$ld device</cds-unit><cds-unit id=\"substitutions.arg2.plural.other\">%2$ld devices</cds-unit></cds-root>"

        XCTAssertEqual(icuRule.0, expectedIcuRule)
        XCTAssertEqual(icuRule.1, .Substitutions)
    }

    func testXLIFFParserWithXCStringsDevices() throws {
        let fileURL = tempXLIFFFileURL()
        let sampleXLIFF = """
<?xml version="1.0" encoding="UTF-8"?>
<xliff xmlns="urn:oasis:names:tc:xliff:document:1.2" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="1.2" xsi:schemaLocation="urn:oasis:names:tc:xliff:document:1.2 http://docs.oasis-open.org/xliff/v1.2/os/xliff-core-1.2-strict.xsd">
  <file original="Localizable.xcstrings" source-language="en" target-language="en" datatype="plaintext">
    <header>
      <tool tool-id="com.apple.dt.xcode" tool-name="Xcode" tool-version="12.3" build-num="12C33"/>
    </header>
    <body>
      <trans-unit id="device|==|device.applevision" xml:space="preserve">
        <source>This is Apple Vision</source>
        <target state="translated">This is Apple Vision</target>
        <note/>
      </trans-unit>
      <trans-unit id="device|==|device.applewatch" xml:space="preserve">
        <source>This is an Apple Watch</source>
        <target state="translated">This is an Apple Watch</target>
        <note/>
      </trans-unit>
      <trans-unit id="device|==|device.iphone" xml:space="preserve">
        <source>This is an iPhone</source>
        <target state="translated">This is an iPhone</target>
        <note/>
      </trans-unit>
      <trans-unit id="device|==|device.mac" xml:space="preserve">
        <source>This is a Mac</source>
        <target state="translated">This is a Mac</target>
        <note/>
      </trans-unit>
      <trans-unit id="device|==|device.other" xml:space="preserve">
        <source>This is a device</source>
        <target state="translated">This is a device</target>
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

        XCTAssertEqual(results.first!.pluralizationRules.count, 5)

        let icuRule = try results.first!.generateICURuleIfPossible().get()

        let expectedIcuRule = "<cds-root><cds-unit id=\"device.applevision\">This is Apple Vision</cds-unit><cds-unit id=\"device.applewatch\">This is an Apple Watch</cds-unit><cds-unit id=\"device.iphone\">This is an iPhone</cds-unit><cds-unit id=\"device.mac\">This is a Mac</cds-unit><cds-unit id=\"device.other\">This is a device</cds-unit></cds-root>"

        XCTAssertEqual(icuRule.0, expectedIcuRule)
        XCTAssertEqual(icuRule.1, .Device)
    }

    func testXLIFFParserWithXCStringsSpecial() throws {
        let fileURL = tempXLIFFFileURL()
        let sampleXLIFF = """
<?xml version="1.0" encoding="UTF-8"?>
<xliff xmlns="urn:oasis:names:tc:xliff:document:1.2" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="1.2" xsi:schemaLocation="urn:oasis:names:tc:xliff:document:1.2 http://docs.oasis-open.org/xliff/v1.2/os/xliff-core-1.2-strict.xsd">
  <file original="Localizable.xcstrings" source-language="en" target-language="en" datatype="plaintext">
    <header>
      <tool tool-id="com.apple.dt.xcode" tool-name="Xcode" tool-version="12.3" build-num="12C33"/>
    </header>
    <body>
    <trans-unit id="weird_key|==|device.iphone" xml:space="preserve">
      <source>Device has %1$#@arg1_iphone@ in %2$ld folders</source>
      <target state="translated">Device has %1$#@arg1_iphone@ in %2$ld folders</target>
      <note/>
    </trans-unit>
    <trans-unit id="weird_key|==|device.other" xml:space="preserve">
      <source>Device has %ld users in %ld folders</source>
      <target state="translated">Device has %ld users in %ld folders</target>
      <note/>
    </trans-unit>
    <trans-unit id="weird_key|==|substitutions.arg1_iphone.plural.one" xml:space="preserve">
      <source>%ld user</source>
      <target state="translated">%ld user</target>
      <note/>
    </trans-unit>
    <trans-unit id="weird_key|==|substitutions.arg1_iphone.plural.other" xml:space="preserve">
      <source>%ld users</source>
      <target state="translated">%ld users</target>
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

        XCTAssertEqual(results.first!.pluralizationRules.count, 4)

        let icuRule = try results.first!.generateICURuleIfPossible().get()

        let expectedIcuRule = "<cds-root><cds-unit id=\"device.iphone\">Device has %1$#@arg1_iphone@ in %2$ld folders</cds-unit><cds-unit id=\"device.other\">Device has %ld users in %ld folders</cds-unit><cds-unit id=\"substitutions.arg1_iphone.plural.one\">%ld user</cds-unit><cds-unit id=\"substitutions.arg1_iphone.plural.other\">%ld users</cds-unit></cds-root>"

        XCTAssertEqual(icuRule.0, expectedIcuRule)
        XCTAssertEqual(icuRule.1, .Device)
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
        ("testXLIFFParserWithXCStrings", testXLIFFParserWithXCStrings),
        ("testXLIFFParserWithStringsDict", testXLIFFParserWithStringsDict),
        ("testXLIFFParserWithXCStringsSubstitutions", testXLIFFParserWithXCStringsSubstitutions),
        ("testXLIFFParserWithXCStringsDevices", testXLIFFParserWithXCStringsDevices),
        ("testXLIFFParserWithXCStringsSpecial", testXLIFFParserWithXCStringsSpecial),
        ("testXLIFFResultConsolidation", testXLIFFResultConsolidation),
        ("testXLIFFParserWithQuotes", testXLIFFParserWithQuotes),
    ]
}
