// swift-tools-version:6.2

// A consumer of opentelemetry-swift that only uses the OTLP/HTTP exporter.
// Scripts/check-trait-pruning.sh checks which packages it resolves.

import Foundation
import PackageDescription

// Comma-separated traits to enable on opentelemetry-swift. Unset means its default traits,
// the same as declaring the dependency without a `traits:` argument.
let traits: Set<Package.Dependency.Trait> =
  ProcessInfo.processInfo.environment["TRAIT_PRUNING_TRAITS"].map { value in
    Set(value.split(separator: ",").map { Package.Dependency.Trait(name: String($0)) })
  } ?? [.defaults]

let package = Package(
  name: "TraitPruning",
  platforms: [
    .macOS(.v12),
    .iOS(.v15),
    .tvOS(.v15),
    .watchOS(.v8),
    .visionOS(.v1),
  ],
  dependencies: [
    .package(name: "opentelemetry-swift", path: "../..", traits: traits)
  ],
  targets: [
    .target(
      name: "TraitPruning",
      dependencies: [
        .product(name: "OpenTelemetryProtocolExporterHTTP", package: "opentelemetry-swift")
      ]
    )
  ]
)
