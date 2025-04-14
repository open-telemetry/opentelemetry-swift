import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import OpenTelemetryProtocolExporterCommon

/// Represents the complete payload sent to Faro collector
public struct FaroPayload: Encodable {
    public let meta: FaroMeta
    public let traces: Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest?
    public let logs: [FaroLog]?
    public let events: [FaroEvent]?
    public let measurements: [FaroMeasurement]?
    public let exceptions: [FaroException]?

    public init(
        meta: FaroMeta,
        traces: Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest? = nil,
        logs: [FaroLog]? = nil,
        events: [FaroEvent]? = nil,
        measurements: [FaroMeasurement]? = nil,
        exceptions: [FaroException]? = nil
    ) {
        self.meta = meta
        self.traces = traces
        self.logs = logs
        self.events = events
        self.measurements = measurements
        self.exceptions = exceptions
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(meta, forKey: .meta)
        
        if let traces = traces {
            let jsonData = try traces.jsonUTF8Data()
            let jsonString = String(data: jsonData, encoding: .utf8)
            try container.encode(jsonString, forKey: .traces)
        }
        
        if let logs = logs {
            try container.encode(logs, forKey: .logs)
        }
        
        if let events = events {
            try container.encode(events, forKey: .events)
        }
        
        if let measurements = measurements {
            try container.encode(measurements, forKey: .measurements)
        }
        
        if let exceptions = exceptions {
            try container.encode(exceptions, forKey: .exceptions)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case meta
        case traces
        case logs
        case events
        case measurements
        case exceptions
    }
}

/// Holds metadata about an app event
public struct FaroMeta: Encodable {
    public let sdk: FaroSdkInfo
    public let app: FaroAppInfo
    public let session: FaroSession
    public let user: FaroUser?
    public let view: FaroView

    public init(sdk: FaroSdkInfo, app: FaroAppInfo, session: FaroSession, user: FaroUser, view: FaroView) {
        self.sdk = sdk
        self.app = app
        self.session = session
        self.user = user
        self.view = view
    }
}

/// Holds metadata about a view
public struct FaroView: Encodable {
    public let name: String
    
    public init(name: String) {
        self.name = name
    }
}

/// Holds metadata about the user related to an app event
public struct FaroUser: Encodable {
    public let id: String?
    public let username: String?
    public let email: String?
    public let attributes: [String: String]
    
    public init(id: String, username: String, email: String, attributes: [String : String]) {
        self.id = id
        self.username = username
        self.email = email
        self.attributes = attributes
    }
}

/// Holds metadata about the browser session the event originates from
public struct FaroSession: Encodable {
    public let id: String
    public let attributes: [String: String]
    
    public init(id: String, attributes: [String: String]) {
        self.id = id
        self.attributes = attributes
    }
}

/// Holds metadata about the app agent that produced the event
public struct FaroSdkInfo: Encodable {
    public let name: String
    public let version: String
    public let integrations: [FaroIntegration]
    
    public init(name: String, version: String, integrations: [FaroIntegration]) {
        self.name = name
        self.version = version
        self.integrations = integrations
    }
}

/// Holds metadata about a plugin/integration on the app agent that collected and sent the event
public struct FaroIntegration: Encodable {
    public let name: String
    public let version: String
    
    public init(name: String, version: String) {
        self.name = name
        self.version = version
    }
}

/// Holds metadata about the application event originates from
public struct FaroAppInfo: Encodable {
    public let name: String?
    public let namespace: String?
    public let version: String?
    public let environment: String?
    public let bundleId: String?
    public let release: String?
    
    public init(name: String?, namespace: String?, version: String?, environment: String?, bundleId: String?, release: String?) {
        self.name = name
        self.namespace = namespace
        self.version = version
        self.environment = environment
        self.bundleId = bundleId
        self.release = release
    }
}

/// Holds trace id and span id associated to an entity (log, exception, measurement...)
public struct FaroTraceContext: Encodable {
    public let traceId: String?
    public let spanId: String?

    enum CodingKeys: String, CodingKey {
        case traceId = "trace_id"
        case spanId = "span_id"
    }

    private init(traceId: String?, spanId: String?) {
        self.traceId = traceId
        self.spanId = spanId
    }
    
    public static func create(traceId: String?, spanId: String?) -> FaroTraceContext? {
        guard traceId?.isEmpty == false || spanId?.isEmpty == false else {
            return nil
        }
        return FaroTraceContext(traceId: traceId, spanId: spanId)
    }
}

/// Holds RUM event data
public struct FaroEvent: Encodable {
    public let name: String
    public let domain: String
    public let attributes: [String: String]
    public let timestamp: String
    public let trace: FaroTraceContext?
    
    public init(
        name: String,
        attributes: [String: String],
        timestamp: String,
        trace: FaroTraceContext?
    ) {
        self.name = name
        self.domain = "swift"
        self.attributes = attributes
        self.timestamp = timestamp
        self.trace = trace
    }
}

/// Holds the data for user provided measurements
public struct FaroMeasurement: Encodable {
    public let type: String
    public let values: [String: Double]
    public let timestamp: String
    public let trace: FaroTraceContext?
    
    init(type: String, values: [String : Double], timestamp: String, trace: FaroTraceContext?) {
        self.type = type
        self.values = values
        self.timestamp = timestamp
        self.trace = trace
    }
}

/// Represents a single stacktrace frame
public struct FaroStacktraceFrame: Encodable {
    public let colno: Int
    public let lineno: Int
    public let filename: String
    public let function: String
    public let module: String
    
    init(colno: Int, lineno: Int, filename: String, function: String, module: String) {
        self.colno = colno
        self.lineno = lineno
        self.filename = filename
        self.function = function
        self.module = module
    }
}

/// Is a collection of Frames
public struct FaroStacktrace: Encodable {
    public let frames: [FaroStacktraceFrame]

    init(frames: [FaroStacktraceFrame]) {
        self.frames = frames
    }
}

/// Holds all the data regarding an exception
public struct FaroException: Encodable {
    public let type: String
    public let value: String
    public let timestamp: String
    public let stacktrace: FaroStacktrace?
    public let context: [String: String]?
    public let trace: FaroTraceContext?
 
    init(type: String, value: String, timestamp: String, stacktrace: FaroStacktrace?, context: [String : String]?, trace: FaroTraceContext?) {
        self.type = type
        self.value = value
        self.timestamp = timestamp
        self.stacktrace = stacktrace
        self.context = context
        self.trace = trace
    }
}

/// Log level enum for incoming app logs
public enum FaroLogLevel: String, Encodable {
    case trace
    case debug
    case info
    case warning
    case error
}

/// Controls the data that come into a Log message
public struct FaroLog: Encodable {
    public let timestamp: String
    public let level: FaroLogLevel
    public let message: String
    public let context: [String: String]?
    public let trace: FaroTraceContext?
        
    init(timestamp: String, level: FaroLogLevel, message: String, context: [String : String]?, trace: FaroTraceContext?) {
        self.timestamp = timestamp
        self.level = level
        self.message = message
        self.context = context
        self.trace = trace
    }
}

/// Error types used throughout the exporter
public enum FaroExporterError: Error, Equatable {
    case invalidCollectorUrl
    case missingApiKey
    case payloadTooLarge
    case networkError(Error)
    case serializationError(Error)
    
    public static func == (lhs: FaroExporterError, rhs: FaroExporterError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidCollectorUrl, .invalidCollectorUrl),
             (.missingApiKey, .missingApiKey),
             (.payloadTooLarge, .payloadTooLarge):
            return true
        case let (.networkError(lhsError), .networkError(rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case let (.serializationError(lhsError), .serializationError(rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

/// Transport-specific errors
public enum TransportError: Error {
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case encodingError(Error)
}

/// Retry-specific errors
public enum RetryError: Error {
    case maxRetriesExceeded
    case circuitBreakerOpen
}

