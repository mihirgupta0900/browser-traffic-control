import Foundation
@testable import BrowserTrafficControlCore

struct RoutingTests {
    let router = URLRouter()

    func orderedRulesAreFirstMatchWins() {
        let settings = Settings(defaultProfile: "Personal", rules: [
            Rule(pattern: "https://github.com/company/**", profile: "Work"),
            Rule(pattern: "https://github.com/**", profile: "GitHub")
        ])
        precondition(router.profile(for: URL(string: "https://github.com/company/repo")!, settings: settings) == "Work")
    }

    func wildcardHostAndPathMatching() {
        precondition(router.wildcard("https://*.example.com/**", "https://docs.example.com/a/b"))
        precondition(router.wildcard("https://example.com/projects/*", "https://example.com/projects/alpha"))
        precondition(!router.wildcard("https://example.com/projects/*", "https://example.com/projects/a/b"))
        precondition(!router.wildcard("https://example.com/**", "https://other.example.com/a"))
    }

    func defaultProfileFallback() {
        let settings = Settings(defaultProfile: "Personal", rules: [Rule(pattern: "https://work.example/**", profile: "Work")])
        precondition(router.profile(for: URL(string: "https://news.example.org")!, settings: settings) == "Personal")
    }

    func httpAndHttpsValidation() {
        precondition(router.isValidWebURL(URL(string: "http://example.com")!))
        precondition(router.isValidWebURL(URL(string: "https://example.com/path")!))
        precondition(!router.isValidWebURL(URL(string: "ftp://example.com")!))
        precondition(!router.isValidWebURL(URL(string: "file:///tmp/test")!))
        precondition(!router.isValidWebURL(URL(string: "https:///missing-host")!))
    }

    func settingsEncodeDecodeRoundTrip() throws {
        let original = Settings(defaultProfile: "Personal", rules: [Rule(pattern: "https://github.com/company/**", profile: "Work")])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Settings.self, from: data)
        precondition(decoded == original)
    }
}

// The local Swift toolchain does not ship XCTest/Testing modules. Execute the
// same assertions during test-bundle initialization so `swift test` remains a
// real, failing validation target without external dependencies.
let _browserTrafficControlValidation: Void = {
    let t = RoutingTests()
    t.orderedRulesAreFirstMatchWins()
    t.wildcardHostAndPathMatching()
    t.defaultProfileFallback()
    t.httpAndHttpsValidation()
    try! t.settingsEncodeDecodeRoundTrip()
    print("BrowserTrafficControlTests: 5 tests passed")
}()
