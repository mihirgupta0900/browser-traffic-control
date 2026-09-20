// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BrowserTrafficControl",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Browser Traffic Control", targets: ["BrowserTrafficControl"]), .library(name: "BrowserTrafficControlCore", targets: ["BrowserTrafficControlCore"])],
    targets: [
        .target(name: "BrowserTrafficControlCore", path: "Sources/BrowserTrafficControlCore"),
        .executableTarget(name: "BrowserTrafficControl", dependencies: ["BrowserTrafficControlCore"], path: "Sources/BrowserTrafficControl"),
        .executableTarget(name: "BrowserTrafficControlBenchmark", dependencies: ["BrowserTrafficControlCore"], path: "Sources/BrowserTrafficControlBenchmark"),
        .executableTarget(name: "BrowserTrafficControlMatchBenchmark", dependencies: ["BrowserTrafficControlCore"], path: "Sources/BrowserTrafficControlMatchBenchmark"),
        .executableTarget(name: "BrowserTrafficControlValidation", dependencies: ["BrowserTrafficControlCore"], path: "Sources/BrowserTrafficControlValidation"),
        .testTarget(name: "BrowserTrafficControlTests", dependencies: ["BrowserTrafficControlCore"], path: "Tests/BrowserTrafficControlTests")
    ]
)
