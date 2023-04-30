/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

/// Provides a framework for detection of resource information from the environment variable
public struct EnvVarHeaders {
    private static let labelListSplitter = Character(",")
    private static let labelKeyValueSplitter = Character("=")

    ///  This resource information is loaded from the 
    ///  environment variable.
    public static let attributes : [(String,String)]? = EnvVarHeaders.attributes()

    public static func attributes(for rawEnvAttributes: String? = ProcessInfo.processInfo.environment["OTEL_EXPORTER_OTLP_HEADERS"]) -> [(String,String)]? {
        parseAttributes(rawEnvAttributes: rawEnvAttributes)
    }

    private init() {}

    private static func isKey(token: String) -> Bool {
        let alpha = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let digit = CharacterSet(charactersIn: "0123456789")
        let special = CharacterSet(charactersIn: "!#$%&'*+-.^_`|~")
        let tchar = special.union(alpha).union(digit)
        return tchar.isSuperset(of: CharacterSet(charactersIn: token))
    }

    private static func isValue(baggage: String) -> Bool {
        let asciiSet = CharacterSet(charactersIn: UnicodeScalar(0) ..< UnicodeScalar(0x80))
        let special = CharacterSet(charactersIn: "^\"|\"$")
        let baggageOctet = asciiSet.subtracting(.controlCharacters).subtracting(.whitespaces).union(special)
        return baggageOctet.isSuperset(of: CharacterSet(charactersIn: baggage))
    }

    /// Creates a label map from the environment variable string.
    /// - Parameter rawEnvLabels: the comma-separated list of labels
    /// NOTE: Parsing does not fully match W3C Correlation-Context
    private static func parseAttributes(rawEnvAttributes: String?) -> [(String, String)]? {
        guard let rawEnvLabels = rawEnvAttributes else { return nil }

        var labels = [(String, String)]()

        rawEnvLabels.split(separator: labelListSplitter).forEach {
            let split = $0.split(separator: labelKeyValueSplitter)
            if split.count != 2 {
                return
            }

            let key = split[0].trimmingCharacters(in: .whitespaces)
            guard isKey(token: key) else { return }

            let value = split[1].trimmingCharacters(in: .whitespaces)
            guard isValue(baggage: value) else { return }

            labels.append((key,value))
        }
        return labels.count > 0 ? labels : nil
    }
}


