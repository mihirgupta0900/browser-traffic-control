import Foundation
import Darwin
import AppKit
import BrowserTrafficControlCore

let iterations = Int(CommandLine.arguments.dropFirst().first ?? "30") ?? 30
func cleanup() { _ = run(["/usr/bin/osascript", "-e", "tell application id \"company.thebrowser.dia\" to repeat with p in profiles of front window\nset n to count of tabs of p\nrepeat with i from n to 1 by -1\nset t to item i of tabs of p\nset u to (URL of t as text)\nif u contains \"example.com/btc-\" or u contains \"browser-traffic-control-\" then close t\nend repeat\nend repeat\nend tell"]) }
defer { cleanup() }
func run(_ args: [String]) -> (Int32, String) { let p = Process(); p.executableURL = URL(fileURLWithPath: args[0]); p.arguments = Array(args.dropFirst()); let out = Pipe(); p.standardOutput = out; p.standardError = out; try? p.run(); p.waitUntilExit(); return (p.terminationStatus, String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "") }
func exists(_ marker: String) -> Bool { let script = "tell application id \"company.thebrowser.dia\" to return (count of (every tab of front window whose URL contains \"\(marker)\")) > 0"; return run(["/usr/bin/osascript", "-e", script]).1.contains("true") }
func sample(cold: Bool) -> Double { if cold { _ = run(["/usr/bin/killall", "Browser Traffic Control"]) }; let marker = "https://example.com/btc-benchmark-\(UUID().uuidString)"; let start = DispatchTime.now().uptimeNanoseconds; _ = run(["/usr/bin/open", "-b", "com.local.browser-traffic-control", marker]); while !exists(marker) && DispatchTime.now().uptimeNanoseconds - start < 10_000_000_000 { usleep(20_000) }; return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000 }
func directSample() -> Double { let marker = "https://example.com/btc-direct-\(UUID().uuidString)"; let start = DispatchTime.now().uptimeNanoseconds; let source = """
on run argv
  set targetProfileName to item 1 of argv
  set targetURL to item 2 of argv
  tell application id "company.thebrowser.dia"
    set matches to (every profile of front window whose name is targetProfileName)
    if (count of matches) is 0 then error "Profile not found"
    make new tab at end of tabs of item 1 of matches with properties {URL:targetURL}
  end tell
end run
"""; _ = run(["/usr/bin/osascript", "-e", source, "--", "Personal", marker]); while !exists(marker) && DispatchTime.now().uptimeNanoseconds - start < 10_000_000_000 { usleep(20_000) }; return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000 }
func noopSample() -> Double { let start = DispatchTime.now().uptimeNanoseconds; _ = run(["/usr/bin/osascript", "-e", "return 1"]); return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000 }
let cachedScript = NSAppleScript(source: "on run argv\nreturn item 1 of argv\nend run")
let cachedDiaScript = NSAppleScript(source: """
on run argv
  set targetProfileName to item 1 of argv
  set targetURL to item 2 of argv
  tell application id "company.thebrowser.dia"
    set matches to (every profile of front window whose name is targetProfileName)
    if (count of matches) is 0 then error "Profile not found"
    make new tab at end of tabs of item 1 of matches with properties {URL:targetURL}
  end tell
end run
""")
func fourCC(_ value: String) -> UInt32 { value.utf8.reduce(0) { ($0 << 8) | UInt32($1) } }
let ascrSuite = fourCC("ascr")
let subroutineEvent = fourCC("psbr")
let subroutineNameKey = fourCC("snam")
var compileError: NSDictionary?
_ = cachedScript?.compileAndReturnError(&compileError)
var diaCompileError: NSDictionary?
_ = cachedDiaScript?.compileAndReturnError(&diaCompileError)
func nativeScriptSample() -> Double { let start = DispatchTime.now().uptimeNanoseconds; let event = NSAppleEventDescriptor.appleEvent(withEventClass: AEEventClass(ascrSuite), eventID: AEEventID(subroutineEvent), targetDescriptor: NSAppleEventDescriptor.currentProcess(), returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID)); event.setParam(NSAppleEventDescriptor(string: "run"), forKeyword: AEKeyword(subroutineNameKey)); let args = NSAppleEventDescriptor.list(); args.insert(NSAppleEventDescriptor(string: "probe"), at: 1); event.setParam(args, forKeyword: AEKeyword(keyDirectObject)); var error: NSDictionary?; _ = cachedScript?.executeAppleEvent(event, error: &error); return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000 }
func nativeDiaSample() -> Double { let marker = "https://example.com/btc-native-\(UUID().uuidString)"; let start = DispatchTime.now().uptimeNanoseconds; let event = NSAppleEventDescriptor.appleEvent(withEventClass: AEEventClass(ascrSuite), eventID: AEEventID(subroutineEvent), targetDescriptor: NSAppleEventDescriptor.currentProcess(), returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID)); event.setParam(NSAppleEventDescriptor(string: "run"), forKeyword: AEKeyword(subroutineNameKey)); let args = NSAppleEventDescriptor.list(); args.insert(NSAppleEventDescriptor(string: "Personal"), at: 1); args.insert(NSAppleEventDescriptor(string: marker), at: 2); event.setParam(args, forKeyword: AEKeyword(keyDirectObject)); var error: NSDictionary?; _ = cachedDiaScript?.executeAppleEvent(event, error: &error); while !exists(marker) && DispatchTime.now().uptimeNanoseconds - start < 10_000_000_000 { usleep(20_000) }; return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000 }
let warm = (0..<iterations).map { _ in sample(cold: false) }
let cold = (0..<max(1, min(10, iterations / 3))).map { _ in sample(cold: true) }
let baseline = (0..<iterations).map { _ in directSample() }
let noop = (0..<iterations).map { _ in noopSample() }
let native = (0..<iterations).map { _ in nativeScriptSample() }
let nativeDia = ProcessInfo.processInfo.environment["BROWSER_TRAFFIC_CONTROL_NATIVE_EXPERIMENT"] == "1" ? (0..<1).map { _ in nativeDiaSample() } : []
print("Warm samples: \(LatencySummary(samples: warm))")
print("Cold samples: \(LatencySummary(samples: cold))")
print("Direct Dia baseline samples: \(LatencySummary(samples: baseline))")
print("osascript no-op spawn floor: \(LatencySummary(samples: noop))")
print("cached NSAppleScript subroutine probe: \(LatencySummary(samples: native)) compile_error=\(compileError != nil)")
if !nativeDia.isEmpty { print("cached NSAppleScript direct Dia experiment: \(LatencySummary(samples: nativeDia)) compile_error=\(diaCompileError != nil)") } else { print("cached NSAppleScript direct Dia experiment: skipped (set BROWSER_TRAFFIC_CONTROL_NATIVE_EXPERIMENT=1; known to block awaiting Dia Apple Event reply in this environment)") }
let warmMedian = LatencySummary(samples: warm).median; let baselineMedian = LatencySummary(samples: baseline).median
print("Warm added overhead vs direct baseline (independent medians): \(warmMedian - baselineMedian) ms")
