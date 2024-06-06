import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import Logging

// let the bridgename be the url of the package?
let bridgename: String = "OTelSwiftLog"
let version: String = "1.0.0"

public struct InstrumentationScope{
    public var name: String
    public var version: String?
    public var eventDomain: String?
    public var schemaUrl: String?
    public var includeTraceContext: Bool?
    public var attributes: [String: AttributeValue]?
}

// Define a custom log handler
struct OTelLogHandler: LogHandler {
    private var scope: InstrumentationScope // Property to store instrumentation scope name
    private var loggerProvider : LoggerProvider  // Property to set LoggerProvider
    private var logger: OpenTelemetryApi.Logger 

    // Define the log level for this handler
    private var _logLevel: Logging.Logger.Level = .info
    public var logLevel: Logging.Logger.Level{
        get {
            return self._logLevel 
        }
        set {
            self._logLevel = newValue
        }
    }

    // Define metadata for this handler
    public var metadata: Logging.Logger.Metadata = [:]
    public subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
        get {
            return self.metadata[key]
        }
        set {
            self.metadata[key] = newValue
        }
    }
    
    // should default logger provider be a noop? or the sdk implementation?
    public init(scope: InstrumentationScope = InstrumentationScope(name: bridgename, version: version),
        loggerProvider: LoggerProvider = OpenTelemetrySdk.LoggerProviderSdk()) {

        self.scope = scope
        self.loggerProvider = loggerProvider
        let loggerBuilder = self.loggerProvider.loggerBuilder(instrumentationScopeName: scope.name)
            .configure(with: scope)
        self.logger = loggerBuilder.build()
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
            "line": AttributeValue.int(Int(line)),
        ]

        // Convert metadata from the method parameter to AttributeValue and assign it to otelattributes
        if let metadata = metadata {
            let methodMetadata = convertMetadata(metadata)
            otelattributes.merge(methodMetadata) { _, new in new }
        }

        // Convert metadata from the struct property to AttributeValue and merge it with otelattributes
        let structMetadata = convertMetadata(self.metadata)
        otelattributes.merge(structMetadata) { _, new in new }

        // Build the log record and emit it
        let event = self.logger.logRecordBuilder().setSeverity(convertSeverity(level: level))
        .setBody(AttributeValue.string(message.description))
        .setAttributes(otelattributes)
      
      if let context = OpenTelemetry.instance.contextProvider.activeSpan?.context {
          _ = event.setSpanContext(context)
      }
        event.emit()

    }



}

extension LoggerBuilder {
    @discardableResult
    func configure(with instrumentationScope: InstrumentationScope) -> LoggerBuilder {
        var builder = self
        
        if let version = instrumentationScope.version {
            builder = builder.setInstrumentationVersion(version)
        }
        
        if let eventDomain = instrumentationScope.eventDomain {
            builder = builder.setEventDomain(eventDomain)
        }
        
        if let schemaUrl = instrumentationScope.schemaUrl {
            builder = builder.setSchemaUrl(schemaUrl)
        }
        
        if let includeTraceContext = instrumentationScope.includeTraceContext {
            builder = builder.setIncludeTraceContext(includeTraceContext)
        }
        
        if let attributes = instrumentationScope.attributes {
            builder = builder.setAttributes(attributes)
        }
        
        return builder
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
func convertToAttributeValue(_ value: Logging.Logger.Metadata.Value) -> AttributeValue? {
    switch value {
    case .dictionary(let nestedDictionary):
        // If value is a nested dictionary, recursively convert it
        var nestedAttributes: [String: AttributeValue] = [:]
        for (nestedKey, nestedValue) in nestedDictionary {
            nestedAttributes[nestedKey] = convertToAttributeValue(nestedValue)
        }
        return AttributeValue.set(AttributeSet(labels: nestedAttributes))
    case .array(let nestedArray):
        // If value is a nested array, recursively convert it
        let nestedValues = nestedArray.map { convertToAttributeValue($0) }
        if let tempArray = nestedValues as? [String] {
            return AttributeValue.stringArray(tempArray)
        } else if let tempArray = nestedValues as? [Int] {
            return AttributeValue.intArray(tempArray)
        } else if let tempArray = nestedValues as? [Double] {
            return AttributeValue.doubleArray(tempArray)
        } else if let tempArray = nestedValues as? [Bool] {
            return AttributeValue.boolArray(tempArray)
        } else {
            return nil
        }
    default:
        // For non-dictionary values, use AttributeValue initializer directly
        return AttributeValue(value)
    }
}    

func convertSeverity(level: Logging.Logger.Level) -> OpenTelemetryApi.Severity{
    switch level {
        case .trace:
            return OpenTelemetryApi.Severity.trace
        case  .debug:
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
            return OpenTelemetryApi.Severity.error2  //should this be fatal instead?
        }
}
