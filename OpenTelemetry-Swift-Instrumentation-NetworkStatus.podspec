Pod::Spec.new do |spec|
  spec.name = "OpenTelemetry-Swift-Instrumentation-NetworkStatus"
  spec.version = "2.0.2"
  spec.summary = "Swift OpenTelemetry Network Status Instrumentation"

  spec.homepage = "https://github.com/open-telemetry/opentelemetry-swift"
  spec.documentation_url = "https://opentelemetry.io/docs/languages/swift"
  spec.license = { :type => "Apache 2.0", :file => "LICENSE" }
  spec.authors = "OpenTelemetry Authors"

  spec.source = { :git => "https://github.com/open-telemetry/opentelemetry-swift.git", :tag => spec.version.to_s }
  spec.source_files = "Sources/Instrumentation/NetworkStatus/*.swift"

  spec.swift_version = "5.10"
  spec.ios.deployment_target = "13.0"
  spec.tvos.deployment_target = "13.0"
  spec.watchos.deployment_target = "6.0"
  spec.visionos.deployment_target = "1.0"
  spec.module_name = "NetworkStatus"

  spec.ios.frameworks = 'CoreTelephony'

  spec.dependency 'OpenTelemetry-Swift-Api', '~> 2.1.1'
  spec.pod_target_xcconfig = { "OTHER_SWIFT_FLAGS" => "-module-name NetworkStatus -package-name opentelemetry_swift_network_status" }

end
