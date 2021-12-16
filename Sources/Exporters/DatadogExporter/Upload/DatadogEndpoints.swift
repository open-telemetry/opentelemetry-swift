/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public enum Endpoint {
    /// US based servers.
    /// Sends data to [app.datadoghq.com](https://app.datadoghq.com/).
    case us1
    /// US3 based servers.
    /// Sends data to [us3.datadoghq.com](https://us3.datadoghq.com/).
    case us3
    /// US based servers.
    /// Sends data to [app.datadoghq.com](https://us5.datadoghq.com/).
    case us5
    /// Europe based servers.
    /// Sends data to [app.datadoghq.eu](https://app.datadoghq.eu/).
    case eu1
    /// Gov servers.
    /// Sends data to [app.ddog-gov.com](https://app.ddog-gov.com/).
    case us1_fed
    /// User-defined server.
    case custom(tracesURL: URL, logsURL: URL, metricsURL: URL)

    @available(*, deprecated, message: "Renamed to us1")
    public static let us: Endpoint = .us1
    @available(*, deprecated, message: "Renamed to eu1")
    public static let eu: Endpoint = .eu1
    @available(*, deprecated, message: "Renamed to us1_fed")
    public static let gov: Endpoint = .us1_fed

    internal var logsURL: URL {
        let endpoint = "api/v2/logs"
        switch self {
            case .us1: return URL(string: "https://logs.browser-intake-datadoghq.com/" + endpoint)!
            case .us3: return URL(string: "https://logs.browser-intake-us3-datadoghq.com/" + endpoint)!
            case .us5: return URL(string: "https://logs.browser-intake-us5-datadoghq.com/" + endpoint)!
            case .eu1: return URL(string: "https://mobile-http-intake.logs.datadoghq.eu/" + endpoint)!
            case .us1_fed: return URL(string: "https://logs.browser-intake-ddog-gov.com/" + endpoint)!
            case let .custom(_, logsURL: logsUrl, _): return logsUrl
        }
    }

    internal var tracesURL: URL {
        let endpoint = "api/v2/spans"
        switch self {
            case .us1: return URL(string: "https://trace.browser-intake-datadoghq.com/" + endpoint)!
            case .us3: return URL(string: "https://trace.browser-intake-us3-datadoghq.com/" + endpoint)!
            case .us5: return URL(string: "https://trace.browser-intake-us5-datadoghq.com/" + endpoint)!
            case .eu1: return URL(string: "https:/public-trace-http-intake.logs.datadoghq.eu/" + endpoint)!
            case .us1_fed: return URL(string: "https://trace.browser-intake-ddog-gov.com/" + endpoint)!
            case let .custom(tracesURL: tracesUrl, _, _): return tracesUrl
        }
    }

    internal var metricsURL: URL {
        let endpoint = "api/v1/series"
        switch self {
            case .us1: return URL(string: "https://api.datadoghq.com/" + endpoint)!
            case .us3: return URL(string: "https://api.us3.datadoghq.com/" + endpoint)!
            case .us5: return URL(string: "https://api.us5.datadoghq.com/" + endpoint)!
            case .eu1: return URL(string: "https://api.datadoghq.eu/" + endpoint)!
            case .us1_fed: return URL(string: "https://api.ddog-gov.com/" + endpoint)!
            case let .custom(_, _, metricsURL: metricsURL): return metricsURL
        }
    }
}
