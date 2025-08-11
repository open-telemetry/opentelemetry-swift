# Custom HTTPClient Example

This example demonstrates how to use a custom HTTPClient implementation with OpenTelemetry HTTP exporters for authentication and other custom behaviors.

## Token Refresh HTTPClient

```swift
import Foundation
import OpenTelemetryProtocolExporterHttp

class AuthTokenHTTPClient: HTTPClient {
    private let session: URLSession
    private var authToken: String?
    private let tokenRefreshURL: URL
    
    init(session: URLSession = URLSession.shared, tokenRefreshURL: URL) {
        self.session = session
        self.tokenRefreshURL = tokenRefreshURL
    }
    
    func send(request: URLRequest, completion: @escaping (Result<HTTPURLResponse, Error>) -> Void) {
        var authorizedRequest = request
        
        // Add auth token if available
        if let token = authToken {
            authorizedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let task = session.dataTask(with: authorizedRequest) { [weak self] data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                // Check if token expired (401)
                if httpResponse.statusCode == 401 {
                    self?.refreshTokenAndRetry(request: request, completion: completion)
                    return
                }
                
                // Handle response normally
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(httpResponse))
                }
            } else if let error = error {
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    private func refreshTokenAndRetry(request: URLRequest, completion: @escaping (Result<HTTPURLResponse, Error>) -> Void) {
        // Implement your token refresh logic here
        var tokenRequest = URLRequest(url: tokenRefreshURL)
        tokenRequest.httpMethod = "POST"
        
        let task = session.dataTask(with: tokenRequest) { [weak self] data, response, error in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let newToken = json["access_token"] as? String {
                self?.authToken = newToken
                // Retry original request with new token
                self?.send(request: request, completion: completion)
            } else {
                completion(.failure(error ?? URLError(.userAuthenticationRequired)))
            }
        }
        task.resume()
    }
}

// Usage
let customHTTPClient = AuthTokenHTTPClient(tokenRefreshURL: URL(string: "https://auth.example.com/token")!)
let exporter = OtlpHttpTraceExporter(
    endpoint: URL(string: "https://api.example.com/v1/traces")!,
    httpClient: customHTTPClient
)
```

## Retry HTTPClient

```swift
class RetryHTTPClient: HTTPClient {
    private let baseClient: HTTPClient
    private let maxRetries: Int
    
    init(baseClient: HTTPClient = BaseHTTPClient(), maxRetries: Int = 3) {
        self.baseClient = baseClient
        self.maxRetries = maxRetries
    }
    
    func send(request: URLRequest, completion: @escaping (Result<HTTPURLResponse, Error>) -> Void) {
        sendWithRetry(request: request, attempt: 0, completion: completion)
    }
    
    private func sendWithRetry(request: URLRequest, attempt: Int, completion: @escaping (Result<HTTPURLResponse, Error>) -> Void) {
        baseClient.send(request: request) { [weak self] result in
            switch result {
            case .success(let response):
                if response.statusCode >= 500 && attempt < self?.maxRetries ?? 0 {
                    // Retry on server errors
                    DispatchQueue.global().asyncAfter(deadline: .now() + pow(2.0, Double(attempt))) {
                        self?.sendWithRetry(request: request, attempt: attempt + 1, completion: completion)
                    }
                } else {
                    completion(result)
                }
            case .failure:
                if attempt < self?.maxRetries ?? 0 {
                    DispatchQueue.global().asyncAfter(deadline: .now() + pow(2.0, Double(attempt))) {
                        self?.sendWithRetry(request: request, attempt: attempt + 1, completion: completion)
                    }
                } else {
                    completion(result)
                }
            }
        }
    }
}
```

## Custom Headers HTTPClient

```swift
class CustomHeadersHTTPClient: HTTPClient {
    private let baseClient: HTTPClient
    private let customHeaders: [String: String]
    
    init(baseClient: HTTPClient = BaseHTTPClient(), customHeaders: [String: String]) {
        self.baseClient = baseClient
        self.customHeaders = customHeaders
    }
    
    func send(request: URLRequest, completion: @escaping (Result<HTTPURLResponse, Error>) -> Void) {
        var modifiedRequest = request
        
        // Add custom headers
        for (key, value) in customHeaders {
            modifiedRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        baseClient.send(request: modifiedRequest, completion: completion)
    }
}

// Usage
let customClient = CustomHeadersHTTPClient(
    customHeaders: [
        "X-API-Key": "your-api-key",
        "X-Client-Version": "1.0.0"
    ]
)
let exporter = OtlpHttpLogExporter(
    endpoint: URL(string: "https://api.example.com/v1/logs")!,
    httpClient: customClient
)
```

## Benefits

Using custom HTTPClient implementations allows you to:

- **Authentication**: Implement OAuth2, API key, or other authentication schemes
- **Retries**: Add exponential backoff retry logic for resilient telemetry export
- **Custom Headers**: Add API keys, client versions, or other required headers
- **Request Modification**: Transform requests before sending (e.g., compression, encryption)
- **Response Handling**: Custom error handling and response processing
- **Testing**: Mock HTTP clients for unit testing exporters