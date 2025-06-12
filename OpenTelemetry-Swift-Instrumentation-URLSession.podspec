Pod::Spec.new do |spec|
  spec.name = "OpenTelemetry-Swift-Instrumentation-URLSession"
  spec.version = "1.16.0"
  spec.summary = "Swift OpenTelemetry URLSession Instrumentation"

  spec.homepage = "https://github.com/open-telemetry/opentelemetry-swift"
  spec.documentation_url = "https://opentelemetry.io/docs/languages/swift"
  spec.license = { :type => "Apache 2.0", :file => "LICENSE" }
  spec.authors = "OpenTelemetry Authors"

  spec.source = { :git => "https://github.com/open-telemetry/opentelemetry-swift.git", :tag => spec.version.to_s }
  spec.source_files = "Sources/Instrumentation/URLSession/*.swift"

  spec.swift_version = "5.10"
  spec.ios.deployment_target = "13.0"
  spec.tvos.deployment_target = "13.0"
  spec.watchos.deployment_target = "6.0"
  spec.module_name = "URLSession"

  spec.dependency 'OpenTelemetry-Swift-Instrumentation-NetworkStatus', spec.version.to_s
  spec.dependency 'OpenTelemetry-Swift-Sdk', spec.version.to_s
  spec.pod_target_xcconfig = { "OTHER_SWIFT_FLAGS" => "-module-name URLSession -package-name opentelemetry_swift_urlsession" }

end
