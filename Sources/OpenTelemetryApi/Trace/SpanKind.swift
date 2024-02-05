/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Type of span. Can be used to specify additional relationships between spans in addition to a
/// parent/child relationship
public enum SpanKind: String, Equatable, Codable {
    /// Default value. Indicates that the span is used internally.
    case `internal`
    /// Indicates that the span covers server-side handling of an RPC or other remote request.
    case server
    /// Indicates that the span covers the client-side wrapper around an RPC or other remote request.
    case client
    /// Indicates that the span describes producer sending a message to a broker. Unlike client and
    /// server, there is no direct critical path latency relationship between producer and consumer
    /// spans.
    case producer
    /// Indicates that the span describes consumer receiving a message from a broker. Unlike client
    /// and server, there is no direct critical path latency relationship between producer and
    /// consumer spans.
    case consumer
}
