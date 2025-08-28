/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import Darwin

/// A minimal HTTP server using only Foundation and POSIX sockets
/// No external dependencies required
class HttpTestServer {
    private var serverSocket: Int32 = -1
    private var serverPort: Int = 0
    private var isRunning = false
    private var serverQueue: DispatchQueue?
    private let serverSemaphore = DispatchSemaphore(value: 0)
    
    // Configuration
    var config: HttpTestServerConfig?
    
    // Server properties
    private var host: String
    private var port: Int
    
    init(url: URL?, config: HttpTestServerConfig?) {
        self.host = url?.host ?? "localhost"
        self.port = url?.port ?? 33333
        self.serverPort = self.port
        self.config = config
    }
    
    func start(semaphore: DispatchSemaphore) throws {
        // Create socket
        serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            throw SocketError.socketCreationFailed
        }
        
        // Allow reuse
        var yes: Int32 = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        
        // Bind to port
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(serverPort).bigEndian
        addr.sin_addr.s_addr = INADDR_ANY
        
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            bind(serverSocket, UnsafeRawPointer(ptr).assumingMemoryBound(to: sockaddr.self), socklen_t(MemoryLayout<sockaddr_in>.size))
        }
        
        guard bindResult >= 0 else {
            close(serverSocket)
            throw SocketError.bindFailed
        }
        
        // Get actual port if auto-assigned
        if serverPort == 0 {
            var addr = sockaddr_in()
            var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            
            let result = withUnsafeMutablePointer(to: &addr) { ptr in
                getsockname(serverSocket, UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: sockaddr.self), &addrLen)
            }
            
            guard result >= 0 else {
                close(serverSocket)
                throw SocketError.portRetrievalFailed
            }
            
            serverPort = Int(addr.sin_port.bigEndian)
        }
        
        // Start listening
        guard listen(serverSocket, 5) >= 0 else {
            close(serverSocket)
            throw SocketError.listenFailed
        }
        
        isRunning = true
        
        // Log server start
        print("Listening on \(host):\(serverPort)...")
        
        // Signal that server is ready
        semaphore.signal()
        
        // Start accept loop on background queue
        serverQueue = DispatchQueue(label: "HttpTestServer", attributes: .concurrent)
        serverQueue?.async { [weak self] in
            self?.acceptLoop()
        }
    }
    
    func stop() {
        print("Client connection closed")
        isRunning = false
        
        // Close server socket
        if serverSocket >= 0 {
            shutdown(serverSocket, SHUT_RDWR)
            close(serverSocket)
            serverSocket = -1
        }
    }
    
    private func acceptLoop() {
        while isRunning {
            var clientAddr = sockaddr_in()
            var clientAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            
            let clientSocket = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                accept(serverSocket, UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: sockaddr.self), &clientAddrLen)
            }
            
            guard clientSocket >= 0 else {
                if !isRunning { break }
                continue
            }
            
            // Handle client on separate queue
            serverQueue?.async { [weak self] in
                self?.handleClient(socket: clientSocket)
            }
        }
    }
    
    private func handleClient(socket: Int32) {
        defer { close(socket) }
        
        // Read request
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = recv(socket, &buffer, buffer.count, 0)
        
        guard bytesRead > 0 else { return }
        
        let requestData = Data(bytes: buffer, count: bytesRead)
        guard let request = String(data: requestData, encoding: .utf8) else { return }
        
        // Parse request
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else { return }
        
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 3 else { return }
        
        let method = parts[0]
        let path = parts[1]
        let version = parts[2]
        
        // Parse headers
        var headers: [String: String] = [:]
        var contentLength = 0
        
        for line in lines.dropFirst() {
            if line.isEmpty { break }
            if let colonIndex = line.firstIndex(of: ":") {
                let key = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                headers[key] = value
                
                if key.lowercased() == "content-length" {
                    contentLength = Int(value) ?? 0
                }
            }
        }
        
        // Generate response based on path
        let response: String
        
        if path.hasPrefix("/success") || path.hasPrefix("/dontinstrument") {
            response = "HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
            
            // Send response
            response.data(using: .utf8)?.withUnsafeBytes { bytes in
                send(socket, bytes.baseAddress, bytes.count, 0)
            }
            
            // Call success callback
            config?.successCallback?()
            
        } else if path.hasPrefix("/forbidden") {
            response = "HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n"
            
            // Send response
            response.data(using: .utf8)?.withUnsafeBytes { bytes in
                send(socket, bytes.baseAddress, bytes.count, 0)
            }
            
            // Call error callback
            config?.errorCallback?()
            
        } else if path.hasPrefix("/error") {
            // Call error callback and close connection without response
            config?.errorCallback?()
            return
            
        } else {
            response = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
            
            // Send response
            response.data(using: .utf8)?.withUnsafeBytes { bytes in
                send(socket, bytes.baseAddress, bytes.count, 0)
            }
        }
    }
    
    enum SocketError: Error, LocalizedError {
        case socketCreationFailed
        case bindFailed
        case listenFailed
        case portRetrievalFailed
        
        var errorDescription: String? {
            switch self {
            case .socketCreationFailed:
                return "Failed to create socket"
            case .bindFailed:
                return "Failed to bind socket"
            case .listenFailed:
                return "Failed to listen on socket"
            case .portRetrievalFailed:
                return "Failed to retrieve port number"
            }
        }
    }
}

// Keep the original types for compatibility
typealias GenericCallback = () -> Void

struct HttpTestServerConfig {
    var successCallback: GenericCallback?
    var errorCallback: GenericCallback?
}
