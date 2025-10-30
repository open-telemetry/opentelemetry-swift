Pod::Spec.new do |spec|
  spec.name = "OpenTelemetry-Swift-Instrumentation-MetricKit"
  spec.version = "2.2.0"
  spec.summary = "Swift OpenTelemetry MetricKit Instrumentation"

  spec.homepage = "https://github.com/open-telemetry/opentelemetry-swift"
  spec.documentation_url = "https://opentelemetry.io/docs/languages/swift"
  spec.license = { :type => "Apache 2.0", :file => "LICENSE" }
  spec.authors = "OpenTelemetry Authors"

  spec.source = { :git => "https://github.com/open-telemetry/opentelemetry-swift.git", :tag => spec.version.to_s }
  spec.source_files = "Sources/Instrumentation/MetricKit/*.swift"
  spec.exclude_files = "Sources/Instrumentation/MetricKit/README.md"

  spec.swift_version = "5.10"
  spec.ios.deployment_target = "13.0"
  spec.osx.deployment_target = "12.0"
  spec.watchos.deployment_target = "6.0"
  spec.visionos.deployment_target = "1.0"
  spec.module_name = "MetricKitInstrumentation"

  spec.dependency 'OpenTelemetry-Swift-Sdk', '~> 2.1.1'
  spec.pod_target_xcconfig = { "OTHER_SWIFT_FLAGS" => "-module-name MetricKitInstrumentation -package-name opentelemetry_swift_metrickit_instrumentation" }

end
