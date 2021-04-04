// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation

public enum SemanticAttributes: String {
    // MARK: General network connection attributes

    /// Transport protocol used.
    ///
    /// **MUST** be one of the following:
    /// - IP.TCP
    /// - IP.UDP
    /// - IP: Another IP-based protocol.
    /// - Unix: Unix Domain socket.
    /// - pipe: Named or anonymous pipe.
    /// - inproc: In-process communication.
    /// - other: Something else (non IP-based).
    case netTransport = "net.transport"
    /// Remote address of the peer (dotted decimal for IPv4 or RFC5952 for IPv6).
    case netPeerIP = "net.peer.ip"
    /// Remote port number as an integer. E.g., 80.
    case netPeerPort = "net.peer.port"
    /// Remote hostname or similar.
    case netPeerName = "net.peer.name"
    /// Like `net.peer.ip` but for the host IP. Useful in case of a multi-IP host.
    case netHostIP = "net.host.ip"
    /// Like `net.peer.port` but for the host port.
    case netHostPort = "net.host.port"
    /// Local hostname or similar.
    case netHostName = "net.host.name"

    // MARK: General remote service attributes
    
    /// The `service.name` of the remote service. **SHOULD** be equal to the actual `service.name` resource attribute of the remote service if any.
    case peerService = "peer.service"
    
    // MARK: General identity attributes

    /// Username or client_id extracted from the access token or Authorization header in the inbound request from outside the system.
    case enduserId = "enduser.id"
    /// Actual/assumed role the client is making the request under extracted from token or application security context.
    case enduserRole = "enduser.role"
    /// Scopes or granted authorities the client currently possesses extracted from token or application security context. The value would come from the scope associated with an OAuth 2.0
    /// Access Token or an attribute value in a SAML 2.0 Assertion.
    case enduserScope = "enduser.scope"

    // MARK: General thread attributes

    /// Current "managed" thread ID (as opposed to OS thread ID).
    case threadId = "thread.id"
    /// Current thread name.
    case threadName = "thread.name"
    
    // MARK: Source Code Attributes
    
    /// The method or function name, or equivalent (usually rightmost part of the code unit's name).
    case codeFunction = "code.function"
    /// The "namespace" within which code.function is defined. Usually the qualified class or module name, such that code.namespace + some separator + code.function form a unique identifier for the code unit.
    case codeNamespace = "code.namespace"
    /// The source code file name that identifies the code unit as uniquely as possible (preferably an absolute file path).
    case codeFilePath = "code.filepath"
    /// The line number in code.filepath best representing the operation. It SHOULD point within the code unit named in code.function.
    case codeLineNumber = "code.lineno"
    
    // MARK: HTTP attributes

    /// HTTP request method. E.g. "GET".
    case httpMethod = "http.method"
    /// Full HTTP request URL in the form scheme://host[:port]/path?query[#fragment].
    case httpURL = "http.url"
    /// The full request target as passed in a HTTP request line or equivalent.
    case httpTarget = "http.target"
    /// The value of the HTTP host header.
    case httpHost = "http.host"
    /// The URI scheme identifying the used protocol: "http" or "https".
    case httpScheme = "http.scheme"
    /// HTTP response status code. E.g. 200 (integer) If and only if one was received/sent.
    case httpStatusCode = "http.status_code"
    /// HTTP reason phrase. E.g. "OK"
    case httpStatusText = "http.status_text"
    /// Kind of HTTP protocol used: "1.0", "1.1", "2", "SPDY" or "QUIC".
    case httpFlavor = "http.flavor"
    /// Value of the HTTP "User-Agent" header sent by the client.
    case httpUserAgent = "http.user_agent"
    /// The primary server name of the matched virtual host. Usually obtained via configuration.
    case httpServerName = "http.server_name"
    /// The matched route (path template).
    case httpRoute = "http.route"
    /// The IP address of the original client behind all proxies, if known.
    case httpClientIP = "http.client_ip"
    /// The size of the request payload body in bytes. This is the number of bytes transferred excluding headers and is often, but not always, present as the Content-Length header. For requests using transport encoding, this should be the compressed size.
    case httpRequestContentLength = "http.request_content_length"
    /// The size of the uncompressed request payload body after transport decoding. Not set if transport encoding not used.
    case httpRequestContentLengthUncompressed = "http.request_content_length_uncompressed"
    /// The size of the response payload body in bytes. This is the number of bytes transferred excluding headers and is often, but not always, present as the Content-Length header. For requests using transport encoding, this should be the compressed size.
    case httpResponseContentLength = "http.response_content_length"
    /// The size of the uncompressed response payload body after transport decoding. Not set if transport encoding not used.
    case httpResponseContentLengthUncompressed = "http.response_content_length_uncompressed"

    // MARK: RPC attributes

    /// A string identifying the remoting system.
    case rpcSystem = "rpc.system"
    /// The name of the method being called, must be equal to the $method part in the span name.
    case rpcMethod = "rpc.method"
    /// The service name, must be equal to the $service part in the span name.
    case rpcService = "rpc.service"
    /// The numeric status code of the gRPC request.
    case grpcStatusCode = "rpc.grpc.status_code"

    // MARK: Messaging attributes

    /// A string identifying the messaging system such as kafka, rabbitmq or activemq.
    case messagingSystem = "messaging.system"
    /// The message destination name, e.g. MyQueue or MyTopic. This might be equal to the span name but is required nevertheless.
    case messagingDestination = "messaging.destination"
    /// The kind of message destination: Either queue or topic.
    case messagingDestination_kind = "messaging.destination_kind"
    /// A boolean that is true if the message destination is temporary.
    case messagingTempDestination = "messaging.temp_destination"
    /// The name of the transport protocol such as AMQP or MQTT.
    case messagingProtocol = "messaging.protocol"
    /// The version of the transport protocol such as 0.9.1.
    case messagingProtocolVersion = "messaging.protocol_version"
    /// Connection string such as tibjmsnaming://localhost:7222 or https://queue.amazonaws.com/80398EXAMPLE/MyQueue.
    case messagingUrl = "messaging.url"
    /// A value used by the messaging system as an identifier for the message, represented as a string.
    case messagingMessageId = "messaging.message_id"
    /// A value identifying the conversation to which the message belongs, represented as a string. Sometimes called "Correlation ID".
    case messagingConversationId = "messaging.conversation_id"
    /// The (uncompressed) size of the message payload in bytes.
    /// Also use this attribute if it is unknown whether the compressed or uncompressed payload size is reported.
    case messagingMessagePayloadSizeBytes = "messaging.message_payload_size_bytes"
    /// The compressed size of the message payload in bytes.
    case messagingMessagePayloadCompressedSizeBytes = "messaging.message_payload_compressed_size_bytes"
    /// A string identifying which part and kind of message consumption this span describes: either receive or process.
    /// (If the operation is send, this attribute must not be set: the operation can be inferred from the span kind in that case.)
    case messagingOperation = "messaging.operation"

    // MARK: Database client attributes

    /// Database type. For any SQL database, "sql". For others, the lower-case database category.
    case dbType = "db.type"
    /// Database instance name.
    case dbInstance = "db.instance"
    /// Database statement for the given database type.
    case dbStatement = "db.statement"
    /// Username for accessing database.
    case dbUser = "db.user"
    /// JDBC substring like "mysql://db.example.com:3306"
    case dbURL = "db.url"
    /// The connection string used to connect to the database. It is recommended to remove embedded credentials.
    case dbConnectionString = "db.connection_string"
    /// If no tech-specific attribute is defined, this attribute is used to report the name of the database being accessed. For commands that switch the database, this should be set to the target database (even if the command fails).
    case dbName = "db.name"
    /// The name of the operation being executed, e.g. the MongoDB command name such as findAndModify, or the SQL keyword
    case dbOperation = "db.operation"

    // MARK: FaaS attributes

    /// Type of the trigger on which the function is executed. It SHOULD be one of the following strings: "datasource", "http", "pubsub", "timer", or "other".
    case faasTrigger = "faas.trigger"
    /// String containing the execution id of the function. E.g. af9d5aa4-a685-4c5f-a22b-444f80b3cc28
    case faasExecution = "faas.execution"
    /// String that refers to the execution environment ID of the function.
    case faasInstance = "faas.instance"
    /// The name of the source on which the operation was perfomed. For example, in Cloud Storage or S3 corresponds to the bucket name, and in Cosmos DB to the database name.
    case faasDocumentCollection = "faas.document.collection"
    /// Describes the type of the operation that was performed on the data. It SHOULD be one of the following strings: "insert", "edit", "delete".
    case faasDocumentOperation = "faas.document.operation"
    /// A string containing the time when the data was accessed in the ISO 8601 format expressed in UTC. E.g. "2020-01-23T13:47:06Z"
    case faasDocumentTime = "faas.document.time"
    /// The document name/table subjected to the operation. For example, in Cloud Storage or S3 is the name of the file, and in Cosmos DB the table name.
    case faasDocumentName = "faas.document.name"
    /// A boolean that is true if the serverless function is executed for the first time (aka cold-start).
    case faasColdStart = "faas.coldstart"
    /// The name of the invoked function
    case faasInvokedName = "faas.invoked_name"
    /// The cloud provider of the invoked function
    case faasInvokedProvider = "faas.invoked_provider"
    /// The cloud region of the invoked function
    case faasInvokedRegion = "faas.invoked_region"
    /// A string containing the function invocation time in the ISO 8601 format expressed in UTC.
    case faasTime = "faas.time"
    /// A string containing the schedule period as Cron Expression.
    case faasCron = "faas.cron"
    
    // MARK: Exception Attributes
    
    /// for use in exception events :  https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/trace/semantic_conventions/exceptions.md
    /// An exception event must be named "exception"
    case exception = "exception";
    /// The type of the exception (its fully-qualified class name, if applicable). The dynamic type of the exception should be preferred over the static type in languages that support it.
    case exceptionType = "exception.type";
    /// SHOULD be set to true if the exception event is recorded at a point where it is known that the exception is escaping the scope of the span.
    case exceptionEscaped = "exception.escaped";
    /// The exception message.
    case exceptionMessage = "exception.message";
    /// A stacktrace as a string in the natural representation for the language runtime. The representation is to be determined and documented by each language SIG.
    case exceptionStackTrace = "exception.stacktrace";
    
    
}
