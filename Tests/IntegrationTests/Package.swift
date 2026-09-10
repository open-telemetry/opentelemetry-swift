// swift-tools-version:6.0
import PackageDescription

// Standalone package so the root `swift test` never picks these targets up:
// the assertions only make sense after Scripts/run-integration-tests.sh has
// driven the demo app against the mock collector.
let package = Package(
  name: "opentelemetry-swift-integration-tests",
  platforms: [
    .macOS(.v12)
  ],
  products: [
    .executable(name: "OTLPMockCollector", targets: ["OTLPMockCollector"])
  ],
  dependencies: [
    .package(name: "opentelemetry-swift", path: "../.."),
    .package(url: "https://github.com/apple/swift-nio.git", from: "2.101.3")
  ],
  targets: [
    .executableTarget(
      name: "OTLPMockCollector",
      dependencies: [
        .product(name: "OpenTelemetryProtocolExporterHTTP", package: "opentelemetry-swift"),
        .product(name: "NIO", package: "swift-nio"),
        .product(name: "NIOHTTP1", package: "swift-nio")
      ],
      path: "MockCollector"
    ),
    .testTarget(
      name: "IntegrationTests",
      dependencies: [],
      path: "Assertions"
    )
  ]
)
