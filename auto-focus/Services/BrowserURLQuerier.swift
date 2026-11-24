import AppKit
import Carbon

/// Reads the active tab's URL from a running browser.
protocol BrowserURLQuerying {
    func fetchURL(from browser: NSRunningApplication, isSafari: Bool) -> (url: String?, errorNumber: Int?)
}

/// The four-char codes of the scripting properties that lead to a browser's current URL.
struct BrowserScriptingCodes: Equatable {
    /// `active tab` of a window; nil for Safari, whose URL is a property of the front document.
    let activeTab: FourCharCode?
    let url: FourCharCode

    /// Codes from Chromium's dictionary, shared by Chrome, Edge, Brave and other Chromium browsers.
    static let chromium = BrowserScriptingCodes(activeTab: 0x6163_5461, url: 0x5552_4C20) // 'acTa', 'URL '
    /// Code from Safari's dictionary for a document's URL.
    static let safari = BrowserScriptingCodes(activeTab: nil, url: 0x7055_524C) // 'pURL'

    /// Reads the codes from a browser's scripting definition (sdef XML).
    static func parse(sdef: Data, isSafari: Bool) -> BrowserScriptingCodes? {
        guard let document = try? XMLDocument(data: sdef) else { return nil }

        if isSafari {
            guard let url = propertyCode(in: document, className: "document", propertyName: "URL") else { return nil }
            return BrowserScriptingCodes(activeTab: nil, url: url)
        }

        guard let activeTab = propertyCode(in: document, className: "window", propertyName: "active tab"),
              let url = propertyCode(in: document, className: "tab", propertyName: "URL") else { return nil }
        return BrowserScriptingCodes(activeTab: activeTab, url: url)
    }

    private static func propertyCode(in document: XMLDocument, className: String, propertyName: String) -> FourCharCode? {
        // Properties can be declared on the class itself or added by a class-extension in another suite
        let xpath = "//*[(self::class and @name='\(className)') or (self::class-extension and @extends='\(className)')]"
            + "/property[@name='\(propertyName)']/@code"
        guard let code = (try? document.nodes(forXPath: xpath))?.first?.stringValue else { return nil }
        return fourCharCode(code)
    }

    static func fourCharCode(_ code: String) -> FourCharCode? {
        let bytes = Array(code.utf8)
        guard bytes.count == 4 else { return nil }
        return bytes.reduce(0) { $0 << 8 | FourCharCode($1) }
    }
}

/// Queries the URL with an Apple Event sent to the browser's process.
///
/// Targeting by process, not by name, matters when two instances of a browser run at once (for
/// example a test-automation Chrome next to the user's own): a script that tells an application by
/// name reaches only one of them, which need not be the one in front.
final class AppleEventBrowserURLQuerier: BrowserURLQuerying {
    /// AppleScript's default timeout; a busy browser can hold a reply that long, and polling waits for it.
    private static let replyTimeout: TimeInterval = 120
    /// Scripting codes per browser bundle ID; only touched from the polling queue.
    private var codesByBundleId: [String: BrowserScriptingCodes] = [:]

    func fetchURL(from browser: NSRunningApplication, isSafari: Bool) -> (url: String?, errorNumber: Int?) {
        guard let codes = scriptingCodes(for: browser, isSafari: isSafari) else {
            return (nil, nil)
        }

        let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(kAECoreSuite),
            eventID: AEEventID(kAEGetData),
            targetDescriptor: NSAppleEventDescriptor(processIdentifier: browser.processIdentifier),
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        event.setParam(Self.urlSpecifier(codes: codes, isSafari: isSafari), forKeyword: AEKeyword(keyDirectObject))

        let reply: NSAppleEventDescriptor
        do {
            reply = try event.sendEvent(options: [.waitForReply], timeout: Self.replyTimeout)
        } catch {
            return (nil, Self.logIfUnexpected((error as NSError).code, browser: browser))
        }

        // The browser reports script errors, such as no open window, in the reply rather than by throwing
        if let errorNumber = reply.paramDescriptor(forKeyword: AEKeyword(keyErrorNumber))?.int32Value, errorNumber != 0 {
            return (nil, Self.logIfUnexpected(Int(errorNumber), browser: browser))
        }

        return (reply.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue, nil)
    }

    private func scriptingCodes(for browser: NSRunningApplication, isSafari: Bool) -> BrowserScriptingCodes? {
        guard let bundleId = browser.bundleIdentifier, let bundleURL = browser.bundleURL else { return nil }
        if let codes = codesByBundleId[bundleId] {
            return codes
        }

        var sdef: Unmanaged<CFData>?
        let status = OSACopyScriptingDefinitionFromURL(bundleURL as CFURL, 0, &sdef)
        let parsed = status == noErr ? (sdef?.takeRetainedValue() as Data?).flatMap {
            BrowserScriptingCodes.parse(sdef: $0, isSafari: isSafari)
        } : nil

        // A dictionary split across included files may not list the property; Safari's and Chromium's codes are the norm
        let codes = parsed ?? (isSafari ? BrowserScriptingCodes.safari : BrowserScriptingCodes.chromium)
        if parsed == nil {
            AppLogger.browser.warning("Browser scripting definition has no URL property — using default codes", metadata: [
                "bundleId": bundleId,
                "status": String(status)
            ])
        }

        codesByBundleId[bundleId] = codes
        return codes
    }

    /// `URL of active tab of window 1`, or `URL of document 1` for Safari.
    private static func urlSpecifier(codes: BrowserScriptingCodes, isSafari: Bool) -> NSAppleEventDescriptor {
        let frontmost = NSAppleEventDescriptor(int32: 1)
        guard let activeTab = codes.activeTab, !isSafari else {
            let document = elementSpecifier(DescType(cDocument), index: frontmost)
            return propertySpecifier(codes.url, of: document)
        }

        let window = elementSpecifier(DescType(cWindow), index: frontmost)
        return propertySpecifier(codes.url, of: propertySpecifier(activeTab, of: window))
    }

    private static func elementSpecifier(_ elementClass: DescType, index: NSAppleEventDescriptor) -> NSAppleEventDescriptor {
        return objectSpecifier(
            desiredClass: elementClass,
            keyForm: DescType(formAbsolutePosition),
            keyData: index,
            container: .null()
        )
    }

    private static func propertySpecifier(_ property: FourCharCode, of container: NSAppleEventDescriptor) -> NSAppleEventDescriptor {
        return objectSpecifier(
            desiredClass: DescType(cProperty),
            keyForm: DescType(formPropertyID),
            keyData: NSAppleEventDescriptor(typeCode: property),
            container: container
        )
    }

    private static func objectSpecifier(
        desiredClass: DescType,
        keyForm: DescType,
        keyData: NSAppleEventDescriptor,
        container: NSAppleEventDescriptor
    ) -> NSAppleEventDescriptor {
        let record = NSAppleEventDescriptor.record()
        record.setDescriptor(NSAppleEventDescriptor(typeCode: desiredClass), forKeyword: AEKeyword(keyAEDesiredClass))
        record.setDescriptor(NSAppleEventDescriptor(enumCode: keyForm), forKeyword: AEKeyword(keyAEKeyForm))
        record.setDescriptor(keyData, forKeyword: AEKeyword(keyAEKeyData))
        record.setDescriptor(container, forKeyword: AEKeyword(keyAEContainer))
        return record.coerce(toDescriptorType: DescType(typeObjectSpecifier)) ?? record
    }

    /// -600 = app not running, -1719/-1728 = no front window/document, -1743 = denied; anything else is logged.
    private static func logIfUnexpected(_ errorNumber: Int, browser: NSRunningApplication) -> Int {
        if ![-600, -1719, -1728, -1743].contains(errorNumber) {
            AppLogger.browser.error("Apple event error for browser", metadata: [
                "bundleId": browser.bundleIdentifier ?? "unknown",
                "error_number": String(errorNumber)
            ])
        }
        return errorNumber
    }
}
