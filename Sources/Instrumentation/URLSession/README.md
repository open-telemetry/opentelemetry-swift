# URL Session instrumentation

This package captures the network calls produced by URLSession. Just by initializing the cl


## Usage 

Initialize the class with  `URLSessionInstrumentation(configuration: URLSessionInstrumentationConfiguration())` to automatically capture all network calls.

This behaviour can be modified or augmented by using the optional callbacks defined in `URLSessionInstrumentationConfiguration` :

`shouldInstrument: ((URLRequest) -> (Bool)?)?` :  Filter which requests you want to instrument, all by default

`shouldRecordPayload: ((URLSession) -> (Bool)?)?`: Implement if you want the session to record payload data, false by default.

`shouldInjectTracingHeaders: ((inout URLRequest) -> (Bool)?)?`: Allows filtering which requests you want to inject headers to follow the trace, true by default. You can also modify the request or add other headers in this method.

`nameSpan: ((URLRequest) -> (String)?)?` - Modifies the name for the given request instead of stantard Opentelemetry name

`createdRequest: ((URLRequest, Span) -> Void)?` - Called after request is created,  it allows to add extra information to the Span

`receivedResponse: ((URLResponse, DataOrFile?, Span) -> Void)?`- Called after response is received,  it allows to add extra information to the Span

`receivedError: ((Error, DataOrFile?, HTTPStatus, Span) -> Void)?` -  Called after an errror is received,  it allows to add extra information to the Span


