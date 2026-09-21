import AppKit
import SwiftUI
import Foundation
import BrowserTrafficControlCore

final class AppModel: ObservableObject {
    @Published var settings = Settings()
    @Published var sampleURL = "https://github.com/company/repository"
    @Published var notice = "Ready to route links"
    @Published var isDefaultHandler = false
    @Published var handlerState: HandlerState = .unavailable
    @Published var handlerStatus = "Checking default-browser status…"
    @Published var profiles: [String] = []
    @Published var profileStatus = "Profiles not loaded"
    @Published var profilesLoading = false
    let store = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("BrowserTrafficControl/settings.json")
    let router = URLRouter()
    init() { load(); refreshDefaultHandler() }
    func handlerMatches(_ scheme: String) -> Bool? {
        guard let url = URL(string: "\(scheme)://example.com"), let resolved = NSWorkspace.shared.urlForApplication(toOpen: url) else { return nil }
        return resolved.standardizedFileURL.path == Bundle.main.bundleURL.standardizedFileURL.path
    }
    func browserEligibility() -> Bool {
        let info = Bundle.main.infoDictionary ?? [:]
        let schemes = ((info["CFBundleURLTypes"] as? [[String: Any]]) ?? []).flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        let contentTypes = ((info["CFBundleDocumentTypes"] as? [[String: Any]]) ?? []).flatMap { $0["LSItemContentTypes"] as? [String] ?? [] }
        return schemes.contains("http") && schemes.contains("https") && contentTypes.contains("public.html")
    }
    func refreshDefaultHandler() {
        let http = handlerMatches("http"); let https = handlerMatches("https")
        handlerState = HandlerStateLogic.classify(http: http, https: https, eligible: browserEligibility())
        isDefaultHandler = handlerState == .configured
        handlerStatus = HandlerStateLogic.explanation(for: handlerState)
    }
    func makeDefaultHandler() {
        let appURL = Bundle.main.bundleURL
        let group = DispatchGroup()
        var errors: [Error] = []
        let errorLock = NSLock()
        for scheme in ["http", "https"] {
            group.enter()
            NSWorkspace.shared.setDefaultApplication(at: appURL, toOpenURLsWithScheme: scheme) { error in
                if let error { errorLock.lock(); errors.append(error); errorLock.unlock() }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            self.refreshDefaultHandler()
            self.notice = errors.isEmpty ? "Default-browser assignment requested; verify it in System Settings" : "macOS did not accept the default-browser assignment"
        }
    }
    func availableProfiles(for current: String? = nil) -> [String] { var result = profiles; if let current, !current.isEmpty, !result.contains(current) { result.insert(current, at: 0) }; return result }
    func refreshProfiles() { profilesLoading = true; profileStatus = "Refreshing Dia profiles…"; DispatchQueue.global().async { let source = """
        tell application id "company.thebrowser.dia"
          if (count of windows) is 0 then launch
          repeat 10 times
            if (count of windows) > 0 then exit repeat
            delay 0.2
          end repeat
          if (count of windows) is 0 then error "Dia has no window"
          set names to {}
          repeat with p in profiles of front window
            set end of names to (name of p as text)
          end repeat
          return names
        end tell
        """; let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript"); p.arguments = ["-e", source]; let out = Pipe(); let err = Pipe(); p.standardOutput = out; p.standardError = err; do { try p.run(); p.waitUntilExit(); let output = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""; let error = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""; DispatchQueue.main.async { self.profilesLoading = false; if p.terminationStatus == 0 { self.profiles = ProfileList.normalize(output); self.profileStatus = self.profiles.isEmpty ? "No Dia profiles found" : "\(self.profiles.count) Dia profiles" } else { self.profileStatus = error.isEmpty ? "Unable to read Dia profiles" : error.trimmingCharacters(in: .whitespacesAndNewlines) } } } catch { DispatchQueue.main.async { self.profilesLoading = false; self.profileStatus = "Unable to query Dia" } } } }
    func load() { if let d = try? Data(contentsOf: store), let value = try? JSONDecoder().decode(Settings.self, from: d) { settings = value } }
    func save() { try? FileManager.default.createDirectory(at: store.deletingLastPathComponent(), withIntermediateDirectories: true); if let d = try? JSONEncoder().encode(settings) { try? d.write(to: store) } }
    func preview() { guard let url = URL(string: sampleURL), router.isValidWebURL(url) else { notice = "Enter a valid http:// or https:// URL"; return }; notice = router.profile(for: url, settings: settings).map { "Matches: Dia · \($0)" } ?? "Matches: Current Dia profile" }
}

struct RuleRow: View {
    @Binding var rule: Rule
    var onDelete: () -> Void
    var onEdit: () -> Void
    var onMoveUp: () -> Void
    var onMoveDown: () -> Void
    var body: some View { HStack(spacing: 12) { Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary).help("Rule order"); VStack(alignment: .leading, spacing: 4) { Text(rule.pattern).font(.body.monospaced()).lineLimit(1); Text("Dia · \(rule.profile)").font(.caption).foregroundStyle(.secondary) }; Spacer(); Button("Edit", action: onEdit).buttonStyle(.borderless).help("Edit rule"); Button(action: onMoveUp) { Image(systemName: "chevron.up") }.buttonStyle(.borderless).help("Move rule up"); Button(action: onMoveDown) { Image(systemName: "chevron.down") }.buttonStyle(.borderless).help("Move rule down"); Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }.buttonStyle(.borderless).help("Delete rule") }.padding(.vertical, 6).accessibilityElement(children: .contain) }
}

struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var showingAdd = false
    @State private var editingID: Rule.ID?
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) { VStack(alignment: .leading, spacing: 6) { Text("Browser Traffic Control").font(.largeTitle.bold()); Text("Route external links to the right browser profile.").foregroundStyle(.secondary) }; Spacer(); Label("Dia backend", systemImage: "bolt.horizontal.circle.fill").foregroundStyle(.secondary).font(.caption).padding(8).background(.quaternary, in: Capsule()) }.padding(.bottom, 22)
            GroupBox { VStack(alignment: .leading, spacing: 12) { HStack { Label("Default-browser setup", systemImage: model.handlerState == .configured ? "checkmark.seal.fill" : "network").font(.headline); Spacer(); if model.handlerState == .configured { Label("HTTP + HTTPS configured", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green) } else { Button("Make Default Browser") { model.makeDefaultHandler() }.buttonStyle(.borderedProminent) }; Button("Check Again") { model.refreshDefaultHandler() }.buttonStyle(.borderless).help("Re-check HTTP and HTTPS handlers") }; Text(model.handlerStatus).font(.caption).foregroundStyle(model.handlerState == .configured ? .secondary : .primary); if model.handlerState != .configured { Text("This utility does not replace or render your browser. It receives external links first, applies your rules, and forwards each link to Dia.").font(.caption).foregroundStyle(.secondary) } } }.padding(.bottom, 18)
            GroupBox { VStack(alignment: .leading, spacing: 10) { HStack { Label("Dia profiles", systemImage: "person.crop.circle").font(.headline); Spacer(); Button { model.refreshProfiles() } label: { Image(systemName: model.profilesLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise") }.buttonStyle(.borderless).help("Refresh profiles from Dia") }; Text("Matched rules target a named profile. Unmatched links open in Dia’s current profile.").font(.caption).foregroundStyle(.secondary); Text(model.profileStatus).font(.caption).foregroundStyle(.tertiary) } }.padding(.bottom, 18)
            HStack { VStack(alignment: .leading, spacing: 3) { Text("Routing rules").font(.headline); Text("First match wins · patterns support * and **").font(.caption).foregroundStyle(.secondary) }; Spacer(); Button { showingAdd = true } label: { Label("Add Rule", systemImage: "plus") }.buttonStyle(.borderedProminent) }.padding(.bottom, 8)
            if model.settings.rules.isEmpty { VStack(spacing: 10) { Image(systemName: "arrow.triangle.branch").font(.system(size: 30)).foregroundStyle(.secondary); Text("No rules yet").font(.headline); Text("Add a rule for work links, personal accounts, or any URL pattern.").font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center) }.frame(maxWidth: .infinity).padding(30).background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12)) } else { List { ForEach($model.settings.rules) { $rule in RuleRow(rule: $rule, onDelete: { if let i = model.settings.rules.firstIndex(where: { $0.id == rule.id }) { model.settings.rules.remove(at: i); model.save() } }, onEdit: { editingID = rule.id }, onMoveUp: { if let i = model.settings.rules.firstIndex(where: { $0.id == rule.id }), i > 0 { model.settings.rules.swapAt(i, i - 1); model.save() } }, onMoveDown: { if let i = model.settings.rules.firstIndex(where: { $0.id == rule.id }), i + 1 < model.settings.rules.count { model.settings.rules.swapAt(i, i + 1); model.save() } }) }.onMove { model.settings.rules.move(fromOffsets: $0, toOffset: $1); model.save() } }.listStyle(.inset).frame(minHeight: 150) }
            Divider().padding(.vertical, 15)
            VStack(alignment: .leading, spacing: 8) { Text("Test a URL").font(.headline); HStack { TextField("https://example.com/path", text: $model.sampleURL).textFieldStyle(.roundedBorder); Button("Preview match") { model.preview() }.buttonStyle(.bordered) }; Text(model.notice).font(.caption).foregroundStyle(model.notice.hasPrefix("Matches") ? .green : .secondary) }
            HStack { Spacer(); Button("Save Changes") { model.save(); model.notice = "Saved" }.keyboardShortcut("s", modifiers: .command).buttonStyle(.borderedProminent) }.padding(.top, 18)
        }.padding(24).frame(minWidth: 650, minHeight: 560).sheet(isPresented: $showingAdd) { RuleEditor(rule: Rule(pattern: "https://github.com/company/**", profile: model.availableProfiles().first ?? ""), title: "Add Routing Rule", profiles: model.availableProfiles()) { rule in model.settings.rules.append(rule); model.save(); showingAdd = false } }
        .sheet(item: Binding(get: { editingID.map { IdentifiedRule(id: $0) } }, set: { editingID = $0?.id })) { item in if let i = model.settings.rules.firstIndex(where: { $0.id == item.id }) { RuleEditor(rule: model.settings.rules[i], title: "Edit Routing Rule", profiles: model.availableProfiles(for: model.settings.rules[i].profile)) { rule in model.settings.rules[i] = rule; model.save(); editingID = nil } } }
    }
}
struct IdentifiedRule: Identifiable { let id: Rule.ID }
struct RuleEditor: View { @State var rule: Rule; var title: String; var profiles: [String]; var onSave: (Rule) -> Void; @Environment(\.dismiss) private var dismiss; var body: some View { VStack(alignment: .leading, spacing: 14) { Text(title).font(.title2.bold()); Text("Use a full URL pattern. ** matches across path segments.").font(.caption).foregroundStyle(.secondary); TextField("URL pattern", text: $rule.pattern).textFieldStyle(.roundedBorder); Picker("Dia profile", selection: $rule.profile) { ForEach(profiles, id: \.self) { name in Text(name).tag(name) } }.pickerStyle(.menu); HStack { Spacer(); Button("Cancel") { dismiss() }; Button("Save") { onSave(rule); dismiss() }.buttonStyle(.borderedProminent) } }.padding(24).frame(width: 430) } }

final class Router: NSObject, NSApplicationDelegate {
    let model = AppModel(); var window: NSWindow?; var queue: [URL] = []; var busy = false; let urlRouter = URLRouter()
    func applicationDidFinishLaunching(_ n: Notification) { buildWindow(); NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleAppleEvent(_:withReplyEvent:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL)) }
    func buildWindow() { guard window == nil else { return }; let hosting = NSHostingController(rootView: ContentView(model: model)); let w = NSWindow(contentViewController: hosting); w.title = "Browser Traffic Control"; w.setContentSize(NSSize(width: 700, height: 650)); w.center(); window = w }
    func showConfigurationWindow() { window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { showConfigurationWindow(); return true }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showConfigurationWindow(); return true }
    func application(_ app: NSApplication, open urls: [URL]) { urls.forEach(enqueue) }
    @objc func handleAppleEvent(_ e: NSAppleEventDescriptor, withReplyEvent: NSAppleEventDescriptor) { if let s = e.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue, let u = URL(string: s) { enqueue(u) } }
    func enqueue(_ u: URL) { let received = DispatchTime.now().uptimeNanoseconds; guard urlRouter.isValidWebURL(u) else { model.notice = "Rejected invalid web URL"; return }; window?.orderOut(nil); queue.append(u); process(received: received) }
    func process(received: UInt64? = nil) { guard !busy, let u = queue.first else { return }; busy = true; queue.removeFirst(); let matched = DispatchTime.now().uptimeNanoseconds; let profile = urlRouter.profile(for: u, settings: model.settings); route(u, profile: profile, received: received ?? matched, matched: matched) }
    func route(_ u: URL, profile: String?, received: UInt64, matched: UInt64) {
        let src: String
        let arguments: [String]
        if let profile {
            src = """
            on run argv
              set targetProfileName to item 1 of argv
              set targetURL to item 2 of argv
              tell application id "company.thebrowser.dia"
                if (count of windows) is 0 then launch
                repeat 10 times
                  if (count of windows) > 0 then exit repeat
                  delay 0.2
                end repeat
                if (count of windows) is 0 then error "Dia has no window"
                set matches to (every profile of front window whose name is targetProfileName)
                if (count of matches) is 0 then error "Profile not found: " & targetProfileName
                if (count of matches) > 1 then error "Profile name is ambiguous: " & targetProfileName
                make new tab at end of tabs of item 1 of matches with properties {URL:targetURL}
              end tell
            end run
            """
            arguments = [profile, u.absoluteString]
        } else {
            src = """
            on run argv
              set targetURL to item 1 of argv
              tell application id "company.thebrowser.dia"
                if (count of windows) is 0 then launch
                repeat 10 times
                  if (count of windows) > 0 then exit repeat
                  delay 0.2
                end repeat
                if (count of windows) is 0 then error "Dia has no window"
                make new tab at end of tabs of front window with properties {URL:targetURL}
              end tell
            end run
            """
            arguments = [u.absoluteString]
        }
        let dispatched = DispatchTime.now().uptimeNanoseconds
        DispatchQueue.global().async { let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript"); p.arguments = ["-e", src, "--"] + arguments; try? p.run(); p.waitUntilExit(); DispatchQueue.main.async { let returned = DispatchTime.now().uptimeNanoseconds; if p.terminationStatus == 0 { NSRunningApplication.runningApplications(withBundleIdentifier: "company.thebrowser.dia").first?.activate(options: [.activateIgnoringOtherApps]); if ProcessInfo.processInfo.environment["BROWSER_TRAFFIC_CONTROL_DIAGNOSTICS"] == "1" { let ms: (UInt64) -> Double = { Double($0) / 1_000_000.0 }; print("route_ms received_to_match=\(ms(matched-received)) dispatch_to_return=\(ms(returned-dispatched)) total=\(ms(returned-received))") } } else { self.model.notice = "Dia could not open the routed link" }; self.busy = false; self.process() } }
    }
}
let app = NSApplication.shared
let delegate = Router()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
