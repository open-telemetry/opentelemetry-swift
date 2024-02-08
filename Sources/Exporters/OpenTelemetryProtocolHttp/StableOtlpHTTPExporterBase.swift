//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryProtocolExporterCommon
import SwiftProtobuf

public class StableOtlpHTTPExporterBase {
    let endpoint: URL
    let httpClient: HTTPClient
    let envVarHeaders: [(String, String)]?
    let config: OtlpConfiguration

    // MARK: - Init

    public init(endpoint: URL, config: OtlpConfiguration = OtlpConfiguration(), useSession: URLSession? = nil, envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes) {
        self.envVarHeaders = envVarHeaders
        self.endpoint = endpoint
        self.config = config
        if let providedSession = useSession {
            httpClient = HTTPClient(session: providedSession)
        } else {
            httpClient = HTTPClient()
        }
    }

    public func createRequest(body: Message, endpoint: URL) -> URLRequest {
        var request = URLRequest(url: endpoint)

        if let headers = envVarHeaders {
            headers.forEach { key, value in
                request.addValue(value, forHTTPHeaderField: key)
            }

        } else if let headers = config.headers {
            headers.forEach { key, value in
                request.addValue(value, forHTTPHeaderField: key)
            }
        }

        do {
            request.httpMethod = "POST"
            request.httpBody = try body.serializedData()
            request.setValue(Headers.getUserAgentHeader(), forHTTPHeaderField: Constants.HTTP.userAgent)
            request.setValue("application/x-protobuf", forHTTPHeaderField: "Content-Type")
        } catch {
            print("Error serializing body: \(error)")
        }

        return request
    }

    public func shutdown(explicitTimeout: TimeInterval? = nil) { }
}
