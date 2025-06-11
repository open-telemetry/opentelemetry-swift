Pod::Spec.new do |spec|
  spec.name = "OpenTelemetry-Swift-BaggagePropagationProcessor"
  spec.version = "1.16.0"
  spec.summary = "Swift OpenTelemetry Baggage Propagation Processor"

  spec.homepage = "https://github.com/open-telemetry/opentelemetry-swift"
  spec.documentation_url = "https://opentelemetry.io/docs/languages/swift"
  spec.license = { :type => "Apache 2.0", :file => "LICENSE" }
  spec.authors = "OpenTelemetry Authors"

  spec.source = { :git => "https://github.com/open-telemetry/opentelemetry-swift.git", :tag => spec.version.to_s }
  spec.source_files = "Sources/Contrib/Processors/BaggagePropagationProcessor/*.swift"

  spec.swift_version = "5.10"
  spec.ios.deployment_target = "13.0"
  spec.tvos.deployment_target = "13.0"
  spec.watchos.deployment_target = "6.0"
  spec.module_name = "BaggagePropagationProcessor"

  spec.dependency 'OpenTelemetry-Swift-Api', spec.version.to_s
  spec.dependency 'OpenTelemetry-Swift-Sdk', spec.version.to_s
  spec.pod_target_xcconfig = { "OTHER_SWIFT_FLAGS" => "-module-name BaggagePropagationProcessor -package-name opentelemetry_swift_baggage_propagation_processor" }

end
