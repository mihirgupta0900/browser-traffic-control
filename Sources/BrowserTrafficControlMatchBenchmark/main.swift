import Foundation
import BrowserTrafficControlCore

let counts = [10, 100, 1_000, 10_000]
let cases = ["first", "middle", "last", "unmatched"]
func summary(_ values: [Double]) -> String { let s = values.sorted(); let p95 = s[Int(Double(s.count - 1) * 0.95)]; return String(format: "median %.3f µs p95 %.3f µs throughput %.0f/s", s[s.count / 2], p95, 1_000_000 / s[s.count / 2]) }
for count in counts {
    let rules = (0..<count).map { Rule(pattern: "https://noise\($0).example/**", profile: "P\($0)") }
    let first = Rule(pattern: "https://target.example/exact", profile: "Target")
    let middle = count / 2
    let last = Rule(pattern: "https://target.example/final/**", profile: "Target")
    for kind in cases {
        var set = rules
        let url: URL
        switch kind { case "first": set[0] = first; url = URL(string: first.pattern)!; case "middle": set[middle] = first; url = URL(string: first.pattern)!; case "last": set[count - 1] = last; url = URL(string: "https://target.example/final/path?q=1#f")!; default: url = URL(string: "https://absent.example/no-match")! }
        let settings = Settings(rules: set); let router = URLRouter(); _ = router.profile(for: url, settings: settings)
        var samples: [Double] = []; samples.reserveCapacity(1_000)
        for _ in 0..<1_000 { let start = DispatchTime.now().uptimeNanoseconds; _ = router.profile(for: url, settings: settings); samples.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000.0) }
        print("rules \(count) \(kind): \(summary(samples))")
    }
}
