/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public struct W3CBaggagePropagator: TextMapBaggagePropagator {
  private static let version = "00"
  private static let delimiter: Character = "-"
  private static let versionLength = 2
  private static let delimiterLength = 1
  private static let versionPrefixIdLength = versionLength + delimiterLength
  private static let traceIdLength = 2 * TraceId.size
  private static let versionAndTraceIdLength = versionLength + delimiterLength + traceIdLength + delimiterLength
  private static let spanIdLength = 2 * SpanId.size
  private static let versionAndTraceIdAndSpanIdLength = versionAndTraceIdLength + spanIdLength + delimiterLength
  private static let optionsLength = 2
  private static let traceparentLengthV0 = versionAndTraceIdAndSpanIdLength + optionsLength

  static let headerBaggage = "baggage"

  private func isValidKeyValuePair(_ keyValue: String) -> (key: String, value: String)? {
    let parts = keyValue.split(separator: "=", maxSplits: 1)
    guard parts.count == 2 else { return nil }

    return (String(parts[0]), String(parts[1]))
  }

  public init() {}

  public let fields: Set<String> = [headerBaggage]

  public func inject(baggage: Baggage, carrier: inout [String: String], setter: some Setter) {
    var headerParts: [String] = []

    for entry in baggage.getEntries() {
      let key = entry.key.name.trimmingCharacters(in: .whitespaces)
      guard !key.isEmpty else { continue }

      // Use UTF-8 percent encoding for the value
      let value = entry.value.string
      let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value

      var part = "\(key)=\(encodedValue)"

      if let metadata = entry.metadata?.metadata, !metadata.isEmpty {
        part += ";\(metadata)"
      }

      headerParts.append(part)
    }

    let headerContent = headerParts.joined(separator: ",")
    if !headerContent.isEmpty {
      setter.set(carrier: &carrier, key: W3CBaggagePropagator.headerBaggage, value: headerContent)
    }
  }

  public func extract(carrier: [String: String], getter: some Getter) -> Baggage? {
    guard let baggageHeaderCollection = getter.get(carrier: carrier, key: W3CBaggagePropagator.headerBaggage),
          let baggageHeader = baggageHeaderCollection.first else {
      return nil
    }

    let builder = OpenTelemetry.instance.baggageManager.baggageBuilder()

    let listMembers = baggageHeader.components(separatedBy: ",")
    for listMember in listMembers {
      let parts = listMember.split(separator: ";", maxSplits: 1)
      guard !parts.isEmpty else { continue }

      // Validate and extract key-value pair
      guard let (key, encodedValue) = isValidKeyValuePair(String(parts[0])),
            let decodedValue = encodedValue.removingPercentEncoding,
            let entryKey = EntryKey(name: key),
            let entryValue = EntryValue(string: decodedValue) else {
        continue
      }

      let metadata = parts.count > 1 ? String(parts[1]) : nil
      builder.put(key: entryKey,
                  value: entryValue,
                  metadata: EntryMetadata(metadata: metadata))
    }

    return builder.build()
  }
}
