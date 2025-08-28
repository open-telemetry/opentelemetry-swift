//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import Darwin
import XCTest
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// A test HTTP server that mimics the API of NIOHTTP1TestServer using POSIX sockets
/// No external dependencies required
public class HttpTestServer {
    private var serverSocket: Int32 = -1
    public private(set) var serverPort: Int = 0
    private var isRunning = false
    private var serverQueue: DispatchQueue?
    
    internal var receivedRequests: [(request: HTTPRequestData, body: Data)] = []
    internal let receivedRequestsQueue = DispatchQueue(label: "HttpTestServer.requests")
    private let startSemaphore = DispatchSemaphore(value: 0)
    
    public init() {}
    
    public func start() throws {
        // Create socket
        serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            throw TestServerError.socketCreationFailed
        }
        
        // Allow reuse
        var yes: Int32 = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        
        // Set non-blocking mode
        let flags = fcntl(serverSocket, F_GETFL, 0)
        if flags >= 0 {
            fcntl(serverSocket, F_SETFL, flags | O_NONBLOCK)
        }
        
        // Bind to port 0 to get a random available port
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0  // Let OS assign a port
        addr.sin_addr.s_addr = INADDR_ANY
        
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            bind(serverSocket, UnsafeRawPointer(ptr).assumingMemoryBound(to: sockaddr.self), socklen_t(MemoryLayout<sockaddr_in>.size))
        }
        
        guard bindResult >= 0 else {
            close(serverSocket)
            throw TestServerError.bindFailed
        }
        
        // Get the assigned port
        var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        withUnsafeMutablePointer(to: &addr) { ptr in
            getsockname(serverSocket, UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: sockaddr.self), &addrLen)
        }
        serverPort = Int(CFSwapInt16BigToHost(addr.sin_port))
        
        // Listen
        guard listen(serverSocket, 10) >= 0 else {
            close(serverSocket)
            throw TestServerError.listenFailed
        }
        
        isRunning = true
        serverQueue = DispatchQueue(label: "HttpTestServer.server")
        
        // Start server thread
        serverQueue?.async { [weak self] in
            self?.serverLoop()
        }
        
        // Give the server a moment to start
        Thread.sleep(forTimeInterval: 0.1)
    }
    
    public func stop() throws {
        isRunning = false
        close(serverSocket)
        serverSocket = -1
        
        receivedRequestsQueue.sync {
            receivedRequests.removeAll()
        }
        
        // Give the server thread time to finish
        Thread.sleep(forTimeInterval: 0.1)
    }
    
    private func serverLoop() {
        // Set socket back to blocking for accept
        let flags = fcntl(serverSocket, F_GETFL, 0)
        if flags >= 0 {
            fcntl(serverSocket, F_SETFL, flags & ~O_NONBLOCK)
        }
        
        while isRunning {
            var clientAddr = sockaddr()
            var clientAddrLen = socklen_t(MemoryLayout<sockaddr>.size)
            
            let clientSocket = accept(serverSocket, &clientAddr, &clientAddrLen)
            if clientSocket < 0 {
                if errno == EBADF { break } // Socket closed
                continue
            }
            
            // Handle client synchronously to avoid timing issues
            handleClient(clientSocket)
        }
    }
    
    private func handleClient(_ clientSocket: Int32) {
        defer { close(clientSocket) }
        
        // Set socket timeout
        var timeout = timeval()
        timeout.tv_sec = 5
        timeout.tv_usec = 0
        setsockopt(clientSocket, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        
        // Read request - we might need to read multiple times for full request
        var totalData = Data()
        var buffer = [UInt8](repeating: 0, count: 8192)
        var contentLength = 0
        var headerEndFound = false
        
        // Read until we have all headers
        while !headerEndFound {
            let bytesRead = recv(clientSocket, &buffer, buffer.count, 0)
            
            if bytesRead <= 0 {
                if bytesRead < 0 && errno == EAGAIN {
                    continue
                }
                break 
            }
            
            totalData.append(contentsOf: buffer[0..<bytesRead])
            
            // Check if we've received the end of headers
            if let dataString = String(data: totalData, encoding: .utf8) {
                if let headerEnd = dataString.range(of: "\r\n\r\n") {
                    headerEndFound = true
                    
                    // Parse Content-Length from headers
                    let headerPart = String(dataString[..<headerEnd.lowerBound])
                    let lines = headerPart.components(separatedBy: "\r\n")
                    for line in lines {
                        if line.lowercased().hasPrefix("content-length:") {
                            let parts = line.split(separator: ":", maxSplits: 1)
                            if parts.count == 2 {
                                contentLength = Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 0
                            }
                        }
                    }
                }
            } else {
                // If we can't convert to string, let's check if we have \r\n\r\n bytes
                if let range = totalData.range(of: Data([0x0D, 0x0A, 0x0D, 0x0A])) {
                    headerEndFound = true
                    // Try to parse headers as ASCII
                    if let headerData = String(data: totalData[..<range.lowerBound], encoding: .ascii) {
                        // Parse Content-Length from ASCII headers
                        let lines = headerData.components(separatedBy: "\r\n")
                        for line in lines {
                            if line.lowercased().hasPrefix("content-length:") {
                                let parts = line.split(separator: ":", maxSplits: 1)
                                if parts.count == 2 {
                                    contentLength = Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 0
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Find the header end position in the data
        guard let headerEndRange = totalData.range(of: Data([0x0D, 0x0A, 0x0D, 0x0A])) else {
            return
        }
        
        let headerEndPosition = headerEndRange.upperBound
        
        // If we have a Content-Length, ensure we've read the full body
        if contentLength > 0 && headerEndFound {
            var currentBodyLength = totalData.count - headerEndPosition
            
            // Read remaining body data if needed
            while currentBodyLength < contentLength {
                let remainingBytes = contentLength - currentBodyLength
                let bytesRead = recv(clientSocket, &buffer, min(buffer.count, remainingBytes), 0)
                guard bytesRead > 0 else { 
                    if bytesRead < 0 && errno == EAGAIN {
                        Thread.sleep(forTimeInterval: 0.01)
                        continue
                    }
                    break 
                }
                totalData.append(contentsOf: buffer[0..<bytesRead])
                currentBodyLength += bytesRead
            }
        }
        
        // Parse the complete HTTP request
        guard let request = parseHttpRequest(nil, rawData: totalData) else { 
            // Send error response
            let errorResponse = """
            HTTP/1.1 400 Bad Request\r
            Content-Length: 0\r
            Connection: close\r
            \r
            
            """
            errorResponse.withCString { ptr in
                send(clientSocket, ptr, strlen(ptr), 0)
            }
            return
        }
        
        // Store the request
        receivedRequestsQueue.sync {
            receivedRequests.append((request: request, body: request.body))
        }
        
        // Send response
        let response = """
        HTTP/1.1 200 OK\r
        Content-Length: 0\r
        Connection: close\r
        \r
        
        """
        
        response.withCString { ptr in
            send(clientSocket, ptr, strlen(ptr), 0)
        }
    }
    
    private func parseHttpRequest(_ requestString: String?, rawData: Data) -> HTTPRequestData? {
        // Find header end in raw data
        guard let headerEndRange = rawData.range(of: Data([0x0D, 0x0A, 0x0D, 0x0A])) else {
            return nil
        }
        
        let headerData = rawData.subdata(in: 0..<headerEndRange.lowerBound)
        
        // Convert header data to string for parsing (headers should be ASCII)
        guard let headerString = String(data: headerData, encoding: .utf8) ?? String(data: headerData, encoding: .ascii) else {
            return nil
        }
        
        let lines = headerString.components(separatedBy: "\r\n")
        guard lines.count > 0 else {
            return nil
        }
        
        // Parse request line
        let requestLineParts = lines[0].components(separatedBy: " ")
        guard requestLineParts.count >= 3 else {
            return nil
        }
        
        let method = requestLineParts[0]
        let path = requestLineParts[1]
        
        // Parse headers
        var headers: [String: String] = [:]
        var contentLength = 0
        
        for i in 1..<lines.count {
            let line = lines[i]
            if let colonIndex = line.firstIndex(of: ":") {
                let name = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                headers[name] = value
                
                // Check for Content-Length header
                if name.lowercased() == "content-length" {
                    contentLength = Int(value) ?? 0
                }
            }
        }
        
        // Extract body from raw data
        var body = Data()
        if contentLength > 0 {
            let bodyStartIndex = headerEndRange.upperBound
            if rawData.count >= bodyStartIndex + contentLength {
                body = rawData.subdata(in: bodyStartIndex..<(bodyStartIndex + contentLength))
            } else if rawData.count > bodyStartIndex {
                // Partial body
                body = rawData.subdata(in: bodyStartIndex..<rawData.count)
            }
        }
        
        return HTTPRequestData(
            method: method,
            path: path,
            headers: headers,
            body: body
        )
    }
    
    /// Receive and verify the HTTP request head
    public func receiveHeadAndVerify(_ verify: (HTTPRequestHead) throws -> Void) throws {
        // Add wait for requests to arrive
        var attempts = 0
        while attempts < 50 {  // Max 5 seconds
            let hasRequests = receivedRequestsQueue.sync {
                return !receivedRequests.isEmpty
            }
            
            if hasRequests {
                break
            }
            
            Thread.sleep(forTimeInterval: 0.1)
            attempts += 1
        }
        
        try receivedRequestsQueue.sync {
            guard let (request, _) = receivedRequests.first else {
                throw TestServerError.noRequestReceived
            }
            
            // Convert to HTTPRequestHead
            let head = HTTPRequestHead(
                method: request.method,
                path: request.path,
                headers: request.headers
            )
            
            try verify(head)
        }
    }
    
    /// Receive and verify the HTTP request body
    public func receiveBodyAndVerify(_ verify: (Data) throws -> Void) throws {
        // Don't wait here since we already waited in the test
        try receivedRequestsQueue.sync {
            guard let (_, bodyData) = receivedRequests.first else {
                throw TestServerError.noRequestReceived
            }
            
            try verify(bodyData)
        }
    }
    
    /// Receive end (for API compatibility)
    public func receiveEnd() throws {
        // This is a no-op since we handle complete requests
    }
    
    /// Clear all received requests
    public func clearReceivedRequests() {
        receivedRequestsQueue.sync {
            receivedRequests.removeAll()
        }
    }
}

/// HTTP request data structure
internal struct HTTPRequestData {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data
}

/// Error types for HttpTestServer
public enum TestServerError: Error, LocalizedError {
    case socketCreationFailed
    case bindFailed
    case listenFailed
    case noRequestReceived
    case noBodyReceived
    
    public var errorDescription: String? {
        switch self {
        case .socketCreationFailed:
            return "Failed to create socket"
        case .bindFailed:
            return "Failed to bind socket"
        case .listenFailed:
            return "Failed to listen on socket"
        case .noRequestReceived:
            return "No request was received by the test server"
        case .noBodyReceived:
            return "No body was received with the request"
        }
    }
}

/// HTTPRequestHead-like structure for compatibility
public struct HTTPRequestHead {
    public let method: String
    public let path: String
    public let headers: [String: String]
    
    /// Helper property to match NIO's API
    public var headers_: HTTPHeaders {
        return HTTPHeaders(headers)
    }
    
    // Add these for compatibility with existing tests
    public var uri: String { return path }
    public var version: HTTPVersion { return .http1_1 }
    public var method_: HTTPMethod {
        return HTTPMethod(rawValue: method)
    }
}

/// HTTPMethod for compatibility
public struct HTTPMethod: Equatable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public static let GET = HTTPMethod(rawValue: "GET")
    public static let POST = HTTPMethod(rawValue: "POST")
    public static let PUT = HTTPMethod(rawValue: "PUT")
    public static let DELETE = HTTPMethod(rawValue: "DELETE")
    public static let HEAD = HTTPMethod(rawValue: "HEAD")
    public static let OPTIONS = HTTPMethod(rawValue: "OPTIONS")
    public static let PATCH = HTTPMethod(rawValue: "PATCH")
}

/// HTTPVersion for compatibility
public enum HTTPVersion: Equatable {
    case http1_1
    case http2
}

/// HTTPHeaders wrapper for compatibility
public struct HTTPHeaders {
    private let headers: [String: String]
    
    init(_ headers: [String: String]) {
        self.headers = headers
    }
    
    public func contains(name: String) -> Bool {
        return headers.keys.contains { $0.lowercased() == name.lowercased() }
    }
    
    public func contains(where predicate: (HTTPHeader) -> Bool) -> Bool {
        for (name, value) in headers {
            if predicate(HTTPHeader(name: name, value: value)) {
                return true
            }
        }
        return false
    }
    
    public func first(name: String) -> String? {
        return headers.first { $0.key.lowercased() == name.lowercased() }?.value
    }
}

/// HTTPHeader for compatibility
public struct HTTPHeader {
    public let name: String
    public let value: String
}

/// HTTPResponseStatus for compatibility
public struct HTTPResponseStatus {
    public let code: UInt
    public let reasonPhrase: String
    
    public static let ok = HTTPResponseStatus(code: 200, reasonPhrase: "OK")
    public static let imATeapot = HTTPResponseStatus(code: 418, reasonPhrase: "I'm a teapot")
}

// Extension to provide ByteBuffer-like functionality
extension Data {
    public func readString(length: Int) -> String? {
        guard count >= length else { return nil }
        return String(data: self.prefix(length), encoding: .utf8)
    }
    
    public var readableBytes: Int {
        return count
    }
}

// ByteBuffer wrapper for compatibility
public struct ByteBuffer {
    private let data: Data
    
    public init(buffer: Data) {
        self.data = buffer
    }
    
    public mutating func readString(length: Int) -> String? {
        return data.readString(length: length)
    }
    
    public var readableBytes: Int {
        return data.readableBytes
    }
}
