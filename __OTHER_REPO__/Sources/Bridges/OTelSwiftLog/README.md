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
