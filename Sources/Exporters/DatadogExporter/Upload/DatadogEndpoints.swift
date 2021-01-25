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

public enum Endpoint {
    /// US based servers.
    /// Sends logs to [app.datadoghq.com](https://app.datadoghq.com/).
    case us
    /// Europe based servers.
    /// Sends logs to [app.datadoghq.eu](https://app.datadoghq.eu/).
    case eu
    /// Gov servers.
    /// Sends logs to [app.ddog-gov.com](https://app.ddog-gov.com/).
    case gov
    /// User-defined server.
    case custom(tracesURL: URL, logsURL: URL, metricsURL: URL)

    internal var logsURL: URL {
        switch self {
            case .us: return URL(string: "https://mobile-http-intake.logs.datadoghq.com/v1/input/")!
            case .eu: return URL(string: "https://mobile-http-intake.logs.datadoghq.eu/v1/input/")!
            case .gov: return URL(string: "https://logs.browser-intake-ddog-gov.com/v1/input/")!
            case let .custom(_, logsURL: logsUrl, _): return logsUrl
        }
    }

    internal var tracesURL: URL {
        switch self {
            case .us: return URL(string: "https://public-trace-http-intake.logs.datadoghq.com/v1/input/")!
            case .eu: return URL(string: "https://public-trace-http-intake.logs.datadoghq.eu/v1/input/")!
            case .gov: return URL(string: "https://trace.browser-intake-ddog-gov.com/v1/input/")!
            case let .custom(tracesURL: tracesUrl, _, _): return tracesUrl
        }
    }

    internal var metricsURL: URL {
        switch self {
            case .us: return URL(string: "https://api.datadoghq.com/api/v1/series/")!
            case .eu: return URL(string: "https://api.datadoghq.eu/api/v1/series/")!
            case .gov: return URL(string: "https://api.ddog-gov.com/api/v1/series/")!
            case let .custom(_, _, metricsURL: metricsURL): return metricsURL
        }
    }

    internal func logsUrlWithClientToken(clientToken: String) throws -> URL {
        if clientToken.isEmpty {
            throw ExporterError(description: "`clientToken` cannot be empty.")
        }
        return logsURL.appendingPathComponent(clientToken)
    }

    internal func tracesUrlWithClientToken(clientToken: String) throws -> URL {
        if clientToken.isEmpty {
            throw ExporterError(description: "`clientToken` cannot be empty.")
        }
        return tracesURL.appendingPathComponent(clientToken)
    }
}
