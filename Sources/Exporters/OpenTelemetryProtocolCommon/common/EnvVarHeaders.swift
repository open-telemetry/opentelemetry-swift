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
  public static let attributes: [(String, String)]? = EnvVarHeaders.attributes()

  public static func attributes(for rawEnvAttributes: String? = ProcessInfo.processInfo.environment["OTEL_EXPORTER_OTLP_HEADERS"]) -> [(String, String)]? {
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
      // Only the first `=` separates the key from the value, so a value may
      // contain one: base64 credentials are often padded with it.
      let split = $0.split(separator: labelKeyValueSplitter, maxSplits: 1)
      if split.count != 2 {
        return
      }

      let key = split[0].trimmingCharacters(in: .whitespaces)
      guard isKey(token: key) else { return }

      let value = split[1].trimmingCharacters(in: .whitespaces)
      guard isValue(baggage: value) else { return }

      labels.append((key, percentDecoded(value)))
    }
    return labels.count > 0 ? labels : nil
  }

  /// Percent-decodes a baggage value, as the W3C Baggage format this variable
  /// follows requires: a code point outside `baggage-octet`, such as the space
  /// in `Authorization=Basic%20Y3JlZA`, is carried percent-encoded. A value
  /// that isn't valid percent-encoding is kept as it is.
  private static func percentDecoded(_ value: String) -> String {
    value.removingPercentEncoding ?? value
  }
}
