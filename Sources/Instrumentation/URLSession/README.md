# URL Session instrumentation

This package captures the network calls produced by URLSession.


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

`receivedError: ((Error, DataOrFile?, HTTPStatus, Span) -> Void)?` -  Called after an errror is received,  it allows to add extra information to the Span


