import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

// let the bridgename be the url of the package?
let bridgename: string = "OTelSwiftLog"
let version: string = "1.0.0"

public struct instrumentationScope{
    public var name: String
    public var version: String
    // Have the rest of params as optional?
    public var eventDomain: String?
    public var schemaUrl: String?
    public var includeTraceContext: Bool?
    public var attributes: [String: AttributeValue]?
}
// Define a custom log handler
struct OTelLogHandler: LogHandler {
    
    // Define the log level for this handler
    public var logLevel: Logger.Level = .info
    var scope: instrumentationScope // Property to store instrumentation scope name
    var loggerProvider : LoggerProvider  // Property to set LoggerProvider
    var logger: Logger 

    // use instrumentationscope
    // should default logger provider be a noop? or the sdk implementation?
    init(scope: instrumentationScope? = instrumentationScope(name: bridgename, version: version), 
        loggerProvider: LoggerProvider? = OpenTelemetrySdk.LoggerProviderSdk) {
        self.scope = scope
        self.loggerProvider = LoggerProvider
        let loggerBuilder = self.loggerProvider.loggerBuilder(instrumentationScope.name)
            .configure(with: instrumentationScope)
        self.logger = loggerBuilder.build()
    }

    func log(level: Logger.Level,
             message: Logger.Message,
             metadata: Logger.Metadata?,
             source: String,
             file: String,
             function: String,
             line: UInt) {

              
        // TODO convert metadata to otel attribute
        var  otelattributes: [String:AttributeValue] = 
                                  ["source": AttributeValue.string(source), 
                                   "file": AttributeValue.string(file),
                                   "function": AttributeValue.string(function),
                                   "line": AttributeValue.string(line),
                                   ]
        let metadataAttributes = metadata?.toAttributes() 
        // let metadataAttributes1 = self.metadata.toAttributes()  

        // otelattributes.merge(metadataAttributes?) { (_, new) in new }
        // otelattributes.merge(metadataAttributes1) { (_, new) in new } 

        logger.logRecordBuilder.setSeverity(convertSeverity(level: level))
        .setSpanContext(OpenTelemetry.instance.contextProvider.activeSpan?.context)
        .setBody(AttributeValue.string(message))
        .setAttributes(otelattribute)
        .emit()
    }
    

    func convertSeverity(level: Logger.level) -> OpenTelemetryApi.Severity{
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

    // should we convert metadata to OTel attributes and store them?
    var metadata: Logger.Metadata = [:]
    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get {
            return metadata[key]
        }
        set {
            metadata[key] = newValue
        }
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

// TODO
extension Logger.Metadata {
    func toAttributes() -> [String: AttributeValue] {
        var attributes: [String: AttributeValue] = [:]
        for (key, value) in self {
            attributes[key] = convertToAttributeValue(value)
        }
        return attributes
    }
    
    private func convertToAttributeValue(_ value: Logger.Metadata.Value) -> AttributeValue {
        switch value {
        case let value as String:
            return AttributeValue.string(value)
        case let value as Int:
            return AttributeValue.int(Int64(value))
        case let value as Double:
            return AttributeValue.double(value)
        // Add more cases for other types as needed
        default:
            // If the type is not supported, convert to string representation
            return AttributeValue.string(String(describing: value))
        }
    }
}