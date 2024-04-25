import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

let bridgename: string = "OTelSwiftLog"
let version: string = "1.0.0"

// Define a custom log handler
struct OTelLogHandler: LogHandler {
    
    // Define the log level for this handler
    public var logLevel: Logger.Level = .info
    var instrumentationScopeName : String // Property to store instrumentation scope name
    var instrumentationVersion : String // Property to store instrumentation scope version
    var loggerProvider : LoggerProvider  // Property to set LoggerProvider
    var logger: Logger 

    // use instrumentationscopename, version to override default values
    // should default logger provider be a noop? or the sdk implementation?
    // also pass label from logger?
    init(instrumentationScopeName: String? = bridgename, 
        instrumentationVersion: String? = version,
        loggerProvider: LoggerProvider? = OpenTelemetrySdk.LoggerProviderSdk) {
        self.instrumentationScopeName = instrumentationScopeName
        self.instrumentationVersion = instrumentationVersion
        self.loggerProvider = LoggerProvider
        self.logger = self.loggerProvider.loggerBuilder(instrumentationScopeName)
                      .setInstrumentationVersion(instrumentationVersion)
                      .build()
    }

    func log(level: Logger.Level,
             message: Logger.Message,
             metadata: Logger.Metadata?,
             source: String,
             file: String,
             function: String,
             line: UInt) {

              
        // TODO convert metadata to otel attribute
        let otelattributes: [String:OpenTelemetryApi.AttributeValue] = 
                                  ["source": OpenTelemetry.AttributeValue.string(source), 
                                   "file": OpenTelemetry.AttributeValue.string(file),
                                   "function":  OpenTelemetry.AttributeValue.string(function),
                                   "line": OpenTelemetry.AttributeValue.string(line)
                                   ]

        logger.logRecordBuilder
            .setSeverity(convertSeverity(level: level))
            .setSpanContext(OpenTelemetry.instance.contextProvider.activeSpan?.context)
            .setBody(OpenTelemetry.AttributeValue.string(message))
            .setAttributes(otelattribute)
            .Emit()
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