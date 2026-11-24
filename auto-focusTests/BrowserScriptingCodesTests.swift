@testable import auto_focus
import XCTest

final class BrowserScriptingCodesTests: XCTestCase {
    private let chromiumSdef = """
    <dictionary>
      <suite name="Chromium Suite" code="CrSu">
        <class name="window" code="cwin">
          <property name="active tab" code="acTa" type="tab" access="r"/>
        </class>
        <class name="tab" code="CrTb">
          <property name="URL" code="URL " type="text"/>
        </class>
        <class name="bookmark item" code="CrBI">
          <property name="URL" code="BURL" type="text"/>
        </class>
      </suite>
    </dictionary>
    """

    private let safariSdef = """
    <dictionary>
      <suite name="Safari suite" code="sfri">
        <class-extension extends="document">
          <property name="URL" code="pURL" type="text"/>
        </class-extension>
        <class-extension extends="tab">
          <property name="URL" code="tURL" type="text"/>
        </class-extension>
      </suite>
    </dictionary>
    """

    func testParsesActiveTabAndTabURLForChromiumBrowsers() throws {
        let codes = try XCTUnwrap(BrowserScriptingCodes.parse(sdef: Data(chromiumSdef.utf8), isSafari: false))

        XCTAssertEqual(codes.activeTab, BrowserScriptingCodes.fourCharCode("acTa"))
        XCTAssertEqual(codes.url, BrowserScriptingCodes.fourCharCode("URL "))
    }

    func testParsesDocumentURLFromClassExtensionForSafari() throws {
        let codes = try XCTUnwrap(BrowserScriptingCodes.parse(sdef: Data(safariSdef.utf8), isSafari: true))

        XCTAssertNil(codes.activeTab)
        XCTAssertEqual(codes.url, BrowserScriptingCodes.fourCharCode("pURL"))
    }

    func testReturnsNilWhenBrowserHasNoActiveTab() {
        XCTAssertNil(BrowserScriptingCodes.parse(sdef: Data(safariSdef.utf8), isSafari: false))
    }

    func testDefaultCodesMatchTheBrowserDictionaries() throws {
        let chromium = try XCTUnwrap(BrowserScriptingCodes.parse(sdef: Data(chromiumSdef.utf8), isSafari: false))
        let safari = try XCTUnwrap(BrowserScriptingCodes.parse(sdef: Data(safariSdef.utf8), isSafari: true))

        XCTAssertEqual(BrowserScriptingCodes.chromium, chromium)
        XCTAssertEqual(BrowserScriptingCodes.safari, safari)
    }

    func testFourCharCodeRequiresFourBytes() {
        XCTAssertEqual(BrowserScriptingCodes.fourCharCode("cwin"), 0x6377_696E)
        XCTAssertNil(BrowserScriptingCodes.fourCharCode("URL"))
    }
}
