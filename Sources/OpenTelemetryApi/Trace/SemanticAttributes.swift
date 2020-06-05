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
    case netTransport = "net.transport"
    /// Remote address of the peer (dotted decimal for IPv4 or RFC5952 for IPv6).
    case netPeerIP = "net.peer.ip"
    /// Remote port number as an integer. E.g., 80.
    case netPeerPort = "net.peer.port"
    /// Remote hostname or similar.
    case netPeerName = "net.peer.name"
    /// Like net.peer.ip but for the host IP. Useful in case of a multi-IP host.
    case netHostIP = "net.host.ip"
    /// Like net.peer.port but for the host port.
    case netHostPort = "net.host.port"
    /// Local hostname or similar.
    case netHostName = "net.host.name"

    // MARK: General identity attributes

    /// Username or client_id extracted from the access token or Authorization header in the inbound request from outside the system.
    case enduserId = "enduser.id"
    /// Actual/assumed role the client is making the request under extracted from token or application security context.
    case enduserRole = "enduser.role"
    /// Scopes or granted authorities the client currently possesses extracted from token or application security context. The value would come from the scope associated with an OAuth 2.0
    /// Access Token or an attribute value in a SAML 2.0 Assertion.
    case enduserScope = "enduser.scope"

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

    // MARK: RPC attributes

    /// The service name, must be equal to the $service part in the span name.
    case rpcService = "rpc.service"

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
}
