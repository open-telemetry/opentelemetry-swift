/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public enum Severity :  Int, Comparable, CustomStringConvertible, Codable {

    case trace=1,
         trace2,
         trace3,
         trace4,
         debug,
         debug2,
         debug3,
         debug4,
         info,
         info2,
         info3,
         info4,
         warn,
         warn2,
         warn3,
         warn4,
         error,
         error2,
         error3,
         error4,
         fatal,
         fatal2,
         fatal3,
         fatal4

    public var description: String {
        switch self {
            case .trace:
                return "TRACE"
            case .trace2:
                return "TRACE2"
            case .trace3:
                return "TRACE3"
            case .trace4:
                return "TRACE4"
            case .debug:
                return "DEBUG"
            case .debug2:
                return "DEBUG2"
            case .debug3:
                return "DEBUG3"
            case .debug4:
                return "DEBUG4"
            case .info:
                return "INFO"
            case .info2:
                return "INFO2"
            case .info3:
                return "INFO3"
            case .info4:
                return "INFO4"
            case .warn:
                return "WARN"
            case .warn2:
                return "WARN2"
            case .warn3:
                return "WARN3"
            case .warn4:
                return "WARN4"
            case .error:
                return "ERROR"
            case .error2:
                return "ERROR2"
            case .error3:
                return "ERROR3"
            case .error4:
                return "ERROR4"
            case .fatal:
                return "FATAL"
            case .fatal2:
                return "FATAL2"
            case .fatal3:
                return "FATAL3"
            case .fatal4:
                return "FATAL4"
        }
    }
    public static func <(lhs: Severity, rhs: Severity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
