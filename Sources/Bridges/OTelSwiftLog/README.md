### How to use OTelLogHandler 

1. Using Default Scope:

```swift
import Foundation
import Logging

// Initialize the OTelLogHandler without a custom scope (using default scope)
let otelLogHandler = OTelLogHandler()

// Create a Logger instance with the default log handler
var logger = Logger(label: "com.example.myapp")
logger.logLevel = .debug
logger.handler = otelLogHandler

// Log messages with various log levels
logger.debug("This is a debug message")

// Log with additional metadata
logger[metadataKey: "customKey"] = "customValue"
logger.info("Logging with additional metadata")
```

2. Using Custom Scope:
```swift
import Foundation
import Logging

// Initialize a custom instrumentation scope
let customScope = InstrumentationScope(
    name: "MyCustomInstrumentationScope",
    version: "1.0.0",
    eventDomain: "MyEventDomain",
    schemaUrl: "https://example.com/schema",
    includeTraceContext: true,
    attributes: ["customAttribute": AttributeValue.string("customValue")]
)

// Initialize the OTelLogHandler with custom scope
let otelLogHandler = OTelLogHandler(scope: customScope)

// Create a Logger instance with the custom log handler
var logger = Logger(label: "com.example.myapp")
logger.logLevel = .debug
logger.handler = otelLogHandler

// Log messages with various log levels
logger.debug("This is a debug message")
```

3. Using Custom Logger Provider:
```swift
import Foundation
import Logging

// Initialize a custom LoggerProvider
let customLoggerProvider = MyCustomLoggerProvider()

// Initialize the OTelLogHandler with custom LoggerProvider and default scope
let otelLogHandler = OTelLogHandler(loggerProvider: customLoggerProvider)

// Create a Logger instance with the custom log handler
var logger = Logger(label: "com.example.myapp")
logger.logLevel = .debug
logger.handler = otelLogHandler

// Log messages with various log levels
logger.debug("This is a debug message")
```

4. Adding Metadata with a Metadata Provider:
```swift
import Foundation
import Logging

enum RequestContext {
  @TaskLocal static var requestID: String?
}

// Metadata returned by the provider is added to every log record.
// It overrides metadata set on the handler, and metadata passed at the
// call site overrides both, matching swift-log's StreamLogHandler.
var otelLogHandler = OTelLogHandler()
otelLogHandler.metadataProvider = Logger.MetadataProvider {
  guard let requestID = RequestContext.requestID else { return [:] }
  return ["request.id": .string(requestID)]
}

var logger = Logger(label: "com.example.myapp")
logger.handler = otelLogHandler

RequestContext.$requestID.withValue("abc-123") {
  // The log record includes the attribute request.id = abc-123
  logger.info("Handling request")
}
```
