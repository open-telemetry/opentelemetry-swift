import Foundation
import OpenTelemetryApi
import Logging

// let the bridgename be the url of the package?
let bridgeName: String = "OTelSwiftLog"
let version: String = "1.0.0"

/// A  custom log handler to translate swift logs into otel logs
public struct OTelLogHandler: LogHandler {
  /// Get or set the configured log level.
  ///
  /// - note: `LogHandler`s must treat the log level as a value type. This means that the change in metadata must
  ///         only affect this very `LogHandler`. It is acceptable to provide some form of global log level override
  ///         that means a change in log level on a particular `LogHandler` might not be reflected in any
  ///        `LogHandler`.
  public var logLevel: Logging.Logger.Level = .info

  /// loggerProvider to use for the bridge.
  private var loggerProvider: LoggerProvider
  private var logger: OpenTelemetryApi.Logger

  // Define metadata for this handler
  public var metadata: Logging.Logger.Metadata = [:]
  public subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
    get {
      return metadata[key]
    }
    set {
      metadata[key] = newValue
    }
  }

  /// create a new OtelLogHandler
  ///  - Parameter loggerProvider: The logger provider to use in the bridge. Defaults to the global logger provider.
  ///  - Parameter includeTraceContext : boolean flag used for the logger builder
  ///  - Parameter attributes: attributes to apply to the logger builder
  public init(loggerProvider: LoggerProvider = OpenTelemetryApi.DefaultLoggerProvider.instance,
              includeTraceContext: Bool = true,
              attributes: [String: AttributeValue] = [String: AttributeValue]()) {
    self.loggerProvider = loggerProvider
    logger = self.loggerProvider.loggerBuilder(instrumentationScopeName: bridgeName)
      .setInstrumentationVersion(version)
      .setEventDomain("device")
      .setIncludeTraceContext(true)
      .setAttributes(attributes)
      .setIncludeTraceContext(includeTraceContext)
      .build()
  }

  public func log(level: Logging.Logger.Level,
                  message: Logging.Logger.Message,
                  metadata: Logging.Logger.Metadata?,
                  source: String,
                  file: String,
                  function: String,
                  line: UInt) {
    // This converts log atrributes to otel attributes
    var otelattributes: [String: AttributeValue] = [
      "source": AttributeValue.string(source),
      "file": AttributeValue.string(file),
      "function": AttributeValue.string(function),
      "line": AttributeValue.int(Int(line))
    ]

    // Convert metadata from the method parameter to AttributeValue and assign it to otelattributes
    if let metadata {
      let methodMetadata = convertMetadata(metadata)
      otelattributes.merge(methodMetadata) { _, new in new }
    }

    // Convert metadata from the struct property to AttributeValue and merge it with otelattributes
    let structMetadata = convertMetadata(self.metadata)
    otelattributes.merge(structMetadata) { _, new in new }

    // Build the log record and emit it
    let event = logger.logRecordBuilder().setSeverity(convertSeverity(level: level))
      .setBody(AttributeValue.string(message.description))
      .setAttributes(otelattributes)

    if let context = OpenTelemetry.instance.contextProvider.activeSpan?.context {
      _ = event.setSpanContext(context)
    }
    event.emit()
  }
}

func convertMetadata(_ metadata: Logging.Logger.Metadata) -> [String: AttributeValue] {
  var convertedAttributes: [String: AttributeValue] = [:]

  // Iterate over each key-value pair in the metadata dictionary
  for (key, value) in metadata {
    // Convert each value to AttributeValue
    let attributeValue = convertToAttributeValue(value)

    // Store the converted value with its corresponding key in the attributes dictionary
    convertedAttributes[key] = attributeValue
  }

  return convertedAttributes
}

// Function to recursively convert nested dictionaries to AttributeValue
func convertToAttributeValue(_ value: Logging.Logger.Metadata.Value) -> AttributeValue {
  switch value {
  case let .dictionary(nestedDictionary):
    // If value is a nested dictionary, recursively convert it
    var nestedAttributes: [String: AttributeValue] = [:]
    for (nestedKey, nestedValue) in nestedDictionary {
      nestedAttributes[nestedKey] = convertToAttributeValue(nestedValue)
    }
    return AttributeValue.set(AttributeSet(labels: nestedAttributes))
  case let .array(nestedArray):
    // If value is a nested array, recursively convert it
    let nestedValues = nestedArray.map { convertToAttributeValue($0) }
    return AttributeValue.array(AttributeArray(values: nestedValues))
  case let .string(str):
    return AttributeValue(str)
  case let .stringConvertible(strConvertable):
    return AttributeValue(strConvertable.description)
  }
}

func convertSeverity(level: Logging.Logger.Level) -> OpenTelemetryApi.Severity {
  switch level {
  case .trace:
    return OpenTelemetryApi.Severity.trace
  case .debug:
    return OpenTelemetryApi.Severity.debug
  case .info:
    return OpenTelemetryApi.Severity.info
  case .notice:
    return OpenTelemetryApi.Severity.info2
  case .warning:
    return OpenTelemetryApi.Severity.warn
  case .error:
    return OpenTelemetryApi.Severity.error
  case .critical:
    return OpenTelemetryApi.Severity.error2 // should this be fatal instead?
  }
}
