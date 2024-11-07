//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

#if canImport(Compression)
import DataCompression
#endif
import Foundation
import SwiftProtobuf
import OpenTelemetryProtocolExporterCommon
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public class OtlpHttpExporterBase {
  let endpoint: URL
  let httpClient: HTTPClient
  let envVarHeaders : [(String,String)]?
  
  let config : OtlpConfiguration
  public init(endpoint: URL, config: OtlpConfiguration = OtlpConfiguration(), useSession: URLSession? = nil, envVarHeaders: [(String,String)]? = EnvVarHeaders.attributes) {
    self.envVarHeaders = envVarHeaders
    
    self.endpoint = endpoint
    self.config = config
    if let providedSession = useSession {
      self.httpClient = HTTPClient(session: providedSession)
    } else {
      self.httpClient = HTTPClient()
    }
  }
  
    public func createRequest(body: Message, endpoint: URL) -> URLRequest {
        var request = URLRequest(url: endpoint)
        
        do {
            let rawData = try body.serializedData()
            request.httpMethod = "POST"
            request.setValue(Headers.getUserAgentHeader(), forHTTPHeaderField: Constants.HTTP.userAgent)
            request.setValue("application/x-protobuf", forHTTPHeaderField: "Content-Type")
            
            var compressedData = rawData
            
#if canImport(Compression)
            switch config.compression {
            case .gzip:
                if let data = rawData.gzip() {
                    compressedData = data
                    request.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
                }
                
            case .deflate:
                if let data = rawData.deflate() {
                    compressedData = data
                    request.setValue("deflate", forHTTPHeaderField: "Content-Encoding")
                }
                
            case .none:
                break
            }
#endif
            // Apply final data. Could be compressed or raw
            // but it doesn't matter here
            request.httpBody = compressedData
        } catch {
            print("Error serializing body: \(error)")
        }
        
        return request
    }
  
  public func shutdown(explicitTimeout: TimeInterval? = nil) {
    
  }
}
