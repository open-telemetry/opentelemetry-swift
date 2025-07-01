Pod::Spec.new do |spec|
  spec.name = "OpenTelemetry-Swift-Api"
  spec.version = "1.17.0"
  spec.summary = "Swift OpenTelemetryApi"

  spec.homepage = "https://github.com/open-telemetry/opentelemetry-swift"
  spec.documentation_url = "https://opentelemetry.io/docs/languages/swift"
  spec.license = { :type => "Apache 2.0", :file => "LICENSE" }
  spec.authors = "OpenTelemetry Authors"

  spec.source = { :git => "https://github.com/open-telemetry/opentelemetry-swift.git", :tag => spec.version.to_s }
  spec.source_files = "Sources/OpenTelemetryApi/**/*.swift"

  spec.swift_version = "5.10"
  spec.ios.deployment_target = "13.0"
  spec.tvos.deployment_target = "13.0"
  spec.watchos.deployment_target = "6.0"
  spec.module_name = "OpenTelemetryApi"
  # This is necessary because we use the `package` keyword to access some properties in `OpenTelemetryApi`
  # This keyword was introduced in Swift 5.9 and it's tightly bound to SPM.
  # To provide the correct values to the flags `-package-name` and `-module-name` we checked out the outputs from:
  # `swift build --verbose`
  spec.pod_target_xcconfig = { "OTHER_SWIFT_FLAGS" => "-module-name OpenTelemetryApi -package-name opentelemetry_swift" }
end
