import Foundation

public struct Rule: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var pattern: String
    public var profile: String
    public init(pattern: String, profile: String) { self.pattern = pattern; self.profile = profile }
}

public struct Settings: Codable, Equatable {
    public var defaultProfile = "Personal"
    public var rules: [Rule] = []
    public init(defaultProfile: String = "Personal", rules: [Rule] = []) { self.defaultProfile = defaultProfile; self.rules = rules }
}

public final class URLRouter {
    private var cachedSettings: Settings?
    private var compiled: [NSRegularExpression] = []
    public init() {}
    public func isValidWebURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https", url.host != nil else { return false }
        return true
    }
    public func profile(for url: URL, settings: Settings) -> String {
        if cachedSettings != settings { cachedSettings = settings; compiled = settings.rules.map { compile($0.pattern) } }
        for (index, rule) in settings.rules.enumerated() where compiled[index].firstMatch(in: url.absoluteString, range: NSRange(url.absoluteString.startIndex..., in: url.absoluteString)) != nil { return rule.profile }
        return settings.defaultProfile
    }
    private func compile(_ pattern: String) -> NSRegularExpression { let escaped = NSRegularExpression.escapedPattern(for: pattern).replacingOccurrences(of: "\\*\\*", with: ".*").replacingOccurrences(of: "\\*", with: "[^/]*"); return (try? NSRegularExpression(pattern: "^" + escaped + "$", options: .caseInsensitive)) ?? (try! NSRegularExpression(pattern: "a^", options: [])) }
    public func wildcard(_ pattern: String, _ value: String) -> Bool {
        return compile(pattern).firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
    }
}

public enum ProfileList {
    public static func normalize(_ output: String) -> [String] {
        var result: [String] = []
        for piece in output.split(whereSeparator: { $0 == "\n" || $0 == "\r" || $0 == "," }) {
            let name = piece.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"{}"))
            if !name.isEmpty && !result.contains(name) { result.append(name) }
        }
        return result
    }
}

public enum HandlerState: Equatable { case configured, partial, notConfigured, unavailable }
public enum HandlerStateLogic {
    public static func classify(http: Bool?, https: Bool?) -> HandlerState {
        guard let http, let https else { return .unavailable }
        if http && https { return .configured }
        if http || https { return .partial }
        return .notConfigured
    }
    public static func explanation(for state: HandlerState) -> String {
        switch state { case .configured: return "External links reach Browser Traffic Control first, then route to Dia."; case .partial: return "Browser Traffic Control handles only one link type. Set both HTTP and HTTPS for complete routing."; case .notConfigured: return "macOS sends external links to the default browser first. Set Browser Traffic Control as default so it can apply your rules, then forward links to Dia."; case .unavailable: return "macOS could not verify the current default-browser assignment." }
    }
}

public enum LaunchIntent { case userInterface, externalURL }
public enum LaunchIntentLogic { public static func shouldShowConfigurationWindow(_ intent: LaunchIntent) -> Bool { intent == .userInterface } }

public struct LatencySummary: Equatable {
    public let count: Int, minimum: Double, median: Double, p95: Double, maximum: Double
    public init(samples: [Double]) { let sorted = samples.sorted(); count = sorted.count; minimum = sorted.first ?? 0; maximum = sorted.last ?? 0; median = sorted.isEmpty ? 0 : sorted[sorted.count / 2]; p95 = sorted.isEmpty ? 0 : sorted[min(sorted.count - 1, Int(Double(sorted.count - 1) * 0.95))] }
}
