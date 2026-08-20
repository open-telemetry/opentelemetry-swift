# URL Session instrumentation

This package captures the network calls produced by URLSession.

This instrumentation relies on the global tracer provider in the `OpenTelemetry` object. Custom global tracer providers must be initialized and set prior to initializing this instrumentation. 

## Usage 

Initialize the class with  `URLSessionInstrumentation(configuration: URLSessionInstrumentationConfiguration())` to automatically capture all network calls.

This behaviour can be modified or augmented by using the optional callbacks defined in `URLSessionInstrumentationConfiguration` :

`shouldInstrument: ((URLRequest) -> (Bool)?)?` :  Filter which requests you want to instrument, all by default

`shouldRecordPayload: ((URLSession) -> (Bool)?)?`: Implement if you want the session to record payload data, false by default.

`shouldInjectTracingHeaders: ((URLRequest) -> (Bool)?)?`: Allows filtering which requests you want to inject headers to follow the trace, true by default. You must also return true if you want to inject custom headers.

`injectCustomHeaders: ((inout URLRequest, Span?) -> Void)?`: Implement this callback to inject custom headers or modify the request in any other way

`nameSpan: ((URLRequest) -> (String)?)?` - Modifies the name for the given request instead of stantard Opentelemetry name

`spanCustomization: ((URLRequest, SpanBuilder) -> Void)?` - Customizes the span while it's being built, such as by adding a parent, a link, attributes, etc.

`createdRequest: ((URLRequest, Span) -> Void)?` - Called after request is created,  it allows to add extra information to the Span

`receivedResponse: ((URLResponse, DataOrFile?, Span) -> Void)?`- Called after response is received,  it allows to add extra information to the Span

`receivedError: ((Error, DataOrFile?, HTTPStatus, Span) -> Void)?` -  Called after an error is received,  it allows to add extra information to the Span

`delegateClassesToInstrument: [AnyClass]?`: The session delegate classes to instrument. When this is `nil`, the instrumentation discovers them by examining **every class loaded in the process** at initialization, which is the default. Passing your delegate classes explicitly skips that search — see [Initialization cost](#initialization-cost) below.

`ignoredClassPrefixes: [String]?`: Class name prefixes to leave out of that search.

`baggageProvider: ((inout URLRequest, Span) -> (Baggage)?)?`: Provides baggage instance for instrumented requests that is merged with active baggage. The callback receives URLRequest and Span parameters to create dynamic baggage based on request context. The resulting baggage is injected into request headers using the configured propagator.

## Initialization cost

Creating `URLSessionInstrumentation` searches every class loaded in the process for session delegate methods, so that delegates are instrumented before any request runs. The cost of that search grows with the number of classes an app links, and in large apps it has been measured in the hundreds of milliseconds. Because it happens during initialization, that time lands on whatever is waiting for it, usually app launch.

If you know your session delegate classes, pass them and the search is skipped entirely:

```swift
URLSessionInstrumentation(
  configuration: URLSessionInstrumentationConfiguration(
    delegateClassesToInstrument: [MyAPIClientDelegate.self, MyUploadDelegate.self]
  )
)
```

Only the classes you list are instrumented, so a delegate you leave out is not, and requests made through it are not captured.

Note that deferring the initialization to get it off the launch path is not equivalent: requests made before the instrumentation exists are not captured, so early network calls go missing instead.
