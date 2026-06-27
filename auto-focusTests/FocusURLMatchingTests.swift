@testable import auto_focus
import Testing

struct FocusURLMatchingTests {
    @Test func domainMatchWithPortRequiresSamePort() {
        let focusURL = FocusURL(name: "Local dev", domain: "localhost:8899")

        #expect(focusURL.matches("http://localhost:8899/issue-245-centering-mockup.html"))
        #expect(!focusURL.matches("http://localhost:3000/issue-245-centering-mockup.html"))
        #expect(!focusURL.matches("http://127.0.0.1:8899/issue-245-centering-mockup.html"))
    }

    @Test func loopbackDomainWithoutPortDoesNotMatchExplicitPort() {
        let focusURL = FocusURL(name: "Localhost", domain: "localhost")
        let ipFocusURL = FocusURL(name: "Loopback IP", domain: "127.0.0.1")

        #expect(focusURL.matches("http://localhost/issue-245-centering-mockup.html"))
        #expect(!focusURL.matches("http://localhost:8899/issue-245-centering-mockup.html"))
        #expect(!focusURL.matches("http://localhost:3000/issue-245-centering-mockup.html"))
        #expect(!ipFocusURL.matches("http://127.0.0.1:8899/issue-245-centering-mockup.html"))
    }

    @Test func nonLoopbackDomainWithoutPortStillMatchesAnyPort() {
        let focusURL = FocusURL(name: "GitHub", domain: "github.com")

        #expect(focusURL.matches("https://github.com/janschill/auto-focus"))
        #expect(focusURL.matches("https://github.com:8443/janschill/auto-focus"))
    }

    @Test func focusTargetKeepsPortFromFullURL() {
        #expect(FocusURL.focusTarget(from: "http://localhost:8899/issue-245-centering-mockup.html") == "localhost:8899")
        #expect(FocusURL.focusTarget(from: "https://www.github.com/janschill/auto-focus") == "github.com")
        #expect(FocusURL.focusTarget(from: "*.example.com:8443/path") == "*.example.com:8443")
    }
}
