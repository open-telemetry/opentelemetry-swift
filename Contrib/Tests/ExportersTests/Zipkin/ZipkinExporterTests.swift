/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest
@testable import ZipkinExporter

class ZipkinExporterTests: XCTestCase {
  func testZipkinExporterIntegration() {
    let spans = [ZipkinSpanConverterTests.createTestSpan()]

    _ = UUID()

    let exporter = ZipkinTraceExporter(options: ZipkinTraceExporterOptions(endpoint: "http://localhost:9090/api/v2/spans?requestId={requestId}"))

    _ = exporter.export(spans: spans)

    let span = spans[0]

    let timestamp = span.startTime.timeIntervalSince1970 * 1000000

    var ipInformation = ""
    if let ipv4 = exporter.localEndPoint.ipv4 {
      ipInformation += #","ipv4":"\#(ipv4)""#
    }

    if let ipv6 = exporter.localEndPoint.ipv6 {
      ipInformation += #","ipv6":"\#(ipv6)""#
    }

    let exporterOutputArray = spans.map { ZipkinConversionExtension.toZipkinSpan(otelSpan: $0, defaultLocalEndpoint: ZipkinTraceExporter.getLocalZipkinEndpoint(name: "Open Telemetry Exporter")) }.map { $0.write() }

    let expectedOutputString = #"{"traceId":"e8ea7e9ac72de94e91fabc613f9686b2","name":"Name","parentId":"\#(span.parentSpanId!.hexString)","id":"\#(span.spanId.hexString)","kind":"CLIENT","timestamp":\#(timestamp),"duration":60000000,"localEndpoint":{"serviceName":"Open Telemetry Exporter"\#(ipInformation)},"annotations":[{"timestamp":\#(timestamp),"value":"Event1"},{"timestamp":\#(timestamp),"value":"Event2"}],"tags":{"stringKey":"value","longKey":"1","longKey2":"1","doubleKey":"1.0","doubleKey2":"1.0","boolKey":"true","otel.status_code":"OK"}}"#
    let expectedData = expectedOutputString.data(using: .utf8)!
    let expectedOutputObject = try? JSONSerialization.jsonObject(with: expectedData)
    let expectedOutput = expectedOutputObject as! NSDictionary

    let exporterOutput = exporterOutputArray[0] as NSDictionary

    compareDictionaries(dict1: exporterOutput, dict2: expectedOutput)
  }
}

func compareDictionaries(dict1: NSDictionary, dict2: NSDictionary) {
  XCTAssertEqual(dict1.count, dict2.count)
  let keys1 = dict1.allKeys.map { $0 as! NSString }
  let keys2 = dict2.allKeys.map { $0 as! NSString }

  for key in keys1 {
    let found = keys2.first { $0 == key }
    XCTAssertNotNil(found)
    if (dict1[key] as? NSDictionary) != nil {
      compareDictionaries(dict1: dict1[key] as! NSDictionary, dict2: dict2[key] as! NSDictionary)
    } else if (dict1[key] as? [Any]) != nil {
      compareArrays(array1: dict1[key] as! [Any], array2: dict2[key] as! [Any])
    } else {
      let object1 = dict1[key] as! NSObject
      let object2 = dict2[key] as! NSObject
      let equal = object1.isEqual(object2)
      if !equal {
        print(" Element error, key: \(key) differs: \(object1.description) VS  \(object2.description)")
      }
      XCTAssertTrue(equal)
    }
  }
}

func compareArrays(array1: [Any], array2: [Any]) {
  let set1 = NSSet(array: array1)
  let set2 = NSSet(array: array2)

  let equal = set1.isEqual(to: set2 as! Set<AnyHashable>)
  if !equal {
    print(" Element error, \(array1) and \(array2) differs")
  }
  XCTAssertTrue(equal)
}
