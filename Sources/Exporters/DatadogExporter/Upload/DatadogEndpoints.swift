/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public enum Endpoint {
    /// US based servers.
    /// Sends logs to [app.datadoghq.com](https://app.datadoghq.com/).
    case us
    /// US3 based servers.
    /// Sends logs to [us3.datadoghq.com](https://us3.datadoghq.com/).
    case us3
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
            case .us3: return URL(string: "https://logs.browser-intake-us3-datadoghq.com/v1/input/")!
            case .eu: return URL(string: "https://mobile-http-intake.logs.datadoghq.eu/v1/input/")!
            case .gov: return URL(string: "https://logs.browser-intake-ddog-gov.com/v1/input/")!
            case let .custom(_, logsURL: logsUrl, _): return logsUrl
        }
    }

    internal var tracesURL: URL {
        switch self {
            case .us: return URL(string: "https://public-trace-http-intake.logs.datadoghq.com/v1/input/")!
            case .us3: return URL(string: "https://trace.browser-intake-us3-datadoghq.com/v1/input/")!
            case .eu: return URL(string: "https://public-trace-http-intake.logs.datadoghq.eu/v1/input/")!
            case .gov: return URL(string: "https://trace.browser-intake-ddog-gov.com/v1/input/")!
            case let .custom(tracesURL: tracesUrl, _, _): return tracesUrl
        }
    }

    internal var metricsURL: URL {
        switch self {
            case .us: return URL(string: "https://api.datadoghq.com/api/v1/series/")!
            case .us3: return URL(string: "https://api.us3.datadoghq.com/api/v1/series/")!
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
