# Session Instrumentation

Automatic session tracking for OpenTelemetry Swift applications. Creates unique session identifiers, tracks session lifecycle events, and automatically adds session context to all telemetry data.

## Features

- **Session Management** - Creates and manages session lifecycles with configurable timeouts and explicit activity
- **Session Events** - Emits OpenTelemetry log records for session start/end events
- **Span Attribution** - Automatically adds session IDs to all spans via span processor
- **Versioned Persistence** - Sessions persist as one versioned record across app restarts
- **Thread Safety** - All components are thread-safe for concurrent access

## Setup

**Basic Setup** (default 30-minute timeout):

```swift
import Sessions
import OpenTelemetrySdk

let sessionManager = SessionManager()
SessionManagerProvider.register(sessionManager: sessionManager)

// Record session start and end events
SessionEventInstrumentation.install()

// Add session attributes to spans
let sessionSpanProcessor = SessionSpanProcessor(sessionManager: sessionManager)
let tracerProvider = TracerProviderBuilder()
    .add(spanProcessor: sessionSpanProcessor)
    .build()

// Add session attributes to log records
let sessionProcessor = SessionLogRecordProcessor(
    nextProcessor: SimpleLogRecordProcessor(logRecordExporter: ConsoleLogRecordExporter()),
    sessionManager: sessionManager
)
let builder = LoggerProviderBuilder()
  .with(processors: [sessionProcessor])
  .with(resource: resource)

// Call this from your app's foreground callback and other meaningful interactions.
func applicationBecameActive() {
    sessionManager.recordActivity()
}
```

**Custom Configuration**:

```swift
let sessionConfig = SessionConfig.builder()
    .with(sessionTimeout: 45 * 60) // 45 minutes
    .with(maxLifetime: 4 * 60 * 60)
    .with(restorePersistedSession: false)
    .build()
let sessionManager = SessionManager(configuration: sessionConfig)
SessionManagerProvider.register(sessionManager: sessionManager)
```

**Custom Persistence**:

```swift
let persistence = UserDefaultsSessionPersistence(
    userDefaults: UserDefaults(suiteName: "group.example.telemetry")!,
    namespace: "mobile-session"
)
let sessionManager = try SessionManager(
    configuration: sessionConfig,
    persistence: persistence,
    persistenceAccess: .exclusive
)
```

**Getting Session Information**:

```swift
// Get the current session and record activity, preserving the existing API behavior
let session = SessionManagerProvider.getInstance().getSession()
print("Session ID: \(session.id)")

// Record a meaningful user interaction or foreground transition
SessionManagerProvider.getInstance().recordActivity()

// End the current session after sign-out and start a linked replacement
SessionManagerProvider.getInstance().resetSession()

// Peek at session without extending it
if let session = SessionManagerProvider.getInstance().peekSession() {
    print("Current session: \(session.id)")
}
```

## Components

### SessionManager

Manages session lifecycle with automatic expiration and explicit activity tracking. Direct
`getSession()` calls continue to record activity for compatibility, while automatic span and log
attribution is passive.

```swift
let manager = SessionManager(configuration: SessionConfig(sessionTimeout: 1800))
let session = manager.getSession() // Creates or retrieves and records activity
manager.recordActivity() // Extends inactivity after meaningful activity
manager.resetSession() // Starts a linked replacement
let current = manager.peekSession() // Peek without creating or extending
```

### SessionManagerProvider

Provides thread-safe singleton access to SessionManager.

```swift
// Register a custom session manager
let manager = SessionManager(configuration: SessionConfig(sessionTimeout: 3600))
SessionManagerProvider.register(sessionManager: manager)

// Access from anywhere
let session = SessionManagerProvider.getInstance().getSession()
```

### SessionSpanProcessor

Automatically adds session IDs to all spans.

```swift
let processor = SessionSpanProcessor(sessionManager: sessionManager)
// Adds session.id and session.previous_id attributes to spans
```

### SessionLogRecordProcessor

Automatically adds session IDs to all log records.

```swift
let processor = SessionLogRecordProcessor(nextProcessor: yourProcessor)
// Adds session.id and session.previous_id attributes to log records
```

### SessionEventInstrumentation

Creates OpenTelemetry log records for session lifecycle events.

```swift
SessionEventInstrumentation.install()
// Emits session.start and session.end log records
```

### Session Model

Represents a session with ID, timestamps, and expiration logic.

```swift
let session = Session(
    id: "unique-session-id",
    expireTime: Date(timeIntervalSinceNow: 1800),
    previousId: "previous-session-id"
)

print("Expired: \(session.isExpired())")
```

## Configuration

### SessionConfig

| Field                     | Type            | Description                                                                 | Default         | Required |
| ------------------------- | --------------- | --------------------------------------------------------------------------- | --------------- | -------- |
| `sessionTimeout`          | `TimeInterval`  | Duration in seconds after which a session expires if left inactive          | `1800` (30 min) | No       |
| `maxLifetime`             | `TimeInterval?` | Maximum duration in seconds a session can remain active, regardless of activity | `nil` (disabled) | No       |
| `restorePersistedSession` | `Bool`          | Whether to resume a saved session as current; when `false`, start a new session and link the saved one as `previous_id` | `true`          | No       |

```swift
let config = SessionConfig.builder()
    .with(sessionTimeout: 30 * 60)
    .with(maxLifetime: 4 * 60 * 60)
    .with(restorePersistedSession: false)
    .build()
```

### Session Timeout Behavior

- Sessions expire after the configured timeout since the most recent recorded activity
- `getSession()` preserves its existing behavior and records activity
- Call `recordActivity()` for meaningful interactions or lifecycle transitions that should extend inactivity
- Span and log processors use passive access, so telemetry and background work do not keep a session alive
- Without a `recordActivity()` call, a session ends at `sessionTimeout`; its duration is zero because no meaningful activity was recorded, and a longer `maxLifetime` does not apply
- Sessions can also expire after `maxLifetime`, even if `recordActivity()` continues to extend inactivity
- `resetSession()` ends the current session and persists one linked replacement
- Set `restorePersistedSession` to `false` to start a new session on each clean application start while linking the persisted session as `previous_id`
- When `restorePersistedSession` is `false`, the persisted session's `session.end` uses its last known activity time, capped at the new session start time
- Expired sessions trigger `session.end` events and create new sessions with `previous_id` links

## Session Events

Emits OpenTelemetry log records following semantic conventions:

### Session Start

A `session.start` log record is created when a new session begins.

**Example session.start Event**:

```json
{
  "eventName": "session.start",
  "timestamp": 1692123456789000000,
  "attributes": {
    "session.id": "550e8400-e29b-41d4-a716-446655440000",
    "session.previous_id": "71260ACC-5286-455F-9955-5DA8C5109A07"
  }
}
```

**Session Start Attributes**:

| Attribute             | Type   | Description                                   | Example                                  |
| --------------------- | ------ | ---------------------------------------------- | ---------------------------------------- |
| `session.id`          | string | Unique identifier for the current session     | `"550e8400-e29b-41d4-a716-446655440000"` |
| `session.previous_id` | string | Identifier of the previous session (if any)   | `"71260ACC-5286-455F-9955-5DA8C5109A07"`                  |

The session's start time is carried on the log record's `timestamp` field, not as an attribute.

### Session End

A `session.end` log record is created when a session expires.

**Example session.end Event**:

```json
{
  "eventName": "session.end",
  "timestamp": 1692125256789000000,
  "attributes": {
    "session.id": "550e8400-e29b-41d4-a716-446655440000",
    "session.previous_id": "71260ACC-5286-455F-9955-5DA8C5109A07"
  }
}
```

**Session End Attributes**:

| Attribute             | Type   | Description                                   | Example                                  |
| --------------------- | ------ | --------------------------------------------- | ---------------------------------------- |
| `session.id`          | string | Unique identifier for the ended session       | `"550e8400-e29b-41d4-a716-446655440000"` |
| `session.previous_id` | string | Identifier of the previous session (if any)   | `"71260ACC-5286-455F-9955-5DA8C5109A07"` |

The session's end time is carried on the log record's `timestamp` field, not as an attribute.

## Span and Log Attribution

`SessionSpanProcessor` and `SessionLogRecordProcessor` automatically add session attributes to all spans and log records:

| Attribute             | Type   | Description                                  | Example                                  |
| --------------------- | ------ | -------------------------------------------- | ---------------------------------------- |
| `session.id`          | string | Current active session identifier            | `"550e8400-e29b-41d4-a716-446655440000"` |
| `session.previous_id` | string | Previous session identifier (when available) | `"71260ACC-5286-455F-9955-5DA8C5109A07"`                  |

**Special Handling**: For `session.start` and `session.end` log records, the processors preserve the existing session attributes rather than overriding them with current session data, ensuring historical accuracy of session events.

## Best Practices

1. **Use SessionManagerProvider** - Register your session manager as a singleton for consistent access
2. **Configure Appropriate Timeouts** - Set session timeouts based on your app's usage patterns
3. **Record Meaningful Activity** - Wire `recordActivity()` to foreground transitions and meaningful user interactions
4. **Add Span Processor Early** - Register the SessionSpanProcessor before creating spans
5. **Handle Session Events** - Set up SessionEventInstrumentation to capture session lifecycle

## Persistence

Sessions are automatically persisted and can be resumed on app restart:

- By default, active persisted sessions continue from their previous state
- Set `restorePersistedSession` to `false` to start a new session on clean start while linking and ending the persisted session
- Expired sessions create new sessions with proper `previous_id` linking
- The built-in backend stores one versioned `Data` record instead of separate fields
- Existing `otel-session-*` fields are migrated when first read
- Session starts and resets are saved immediately
- Activity updates are coalesced and saved on a 30-second timer to minimize disk I/O

### Ownership

The default manager uses `UserDefaults.standard` and is intended to be the only writer in its process. Use `SessionManagerProvider` instead of creating multiple default managers. App extensions use their own standard defaults container and therefore start an independent session chain.

`UserDefaultsSessionPersistence` accepts a suite and namespace, including an App Group suite, but one app or extension must own that record at a time. Requesting `.shared` access is currently rejected for every backend because a session transition requires an atomic cross-process read, update, and write. Use separate namespaces for independent processes until shared transitions have an explicit coordination API.

## Thread Safety

All components are designed for concurrent access:

- `SessionManager` uses locks for thread-safe session access
- Concurrent lifecycle effects are published in session order without making one caller wait on another thread's exporter or observer callbacks
- `SessionManagerProvider` provides thread-safe singleton access
- `SessionStore` handles concurrent persistence operations safely
