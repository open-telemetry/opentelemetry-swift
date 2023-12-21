/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
public class LogRecordAdapter {
  public static func toProtoResourceRecordLog(logRecordList: [ReadableLogRecord]) -> [Opentelemetry_Proto_Logs_V1_ResourceLogs] {
    let resourceAndScopeMap = groupByResourceAndScope(logRecordList: logRecordList)
    var resourceLogs = [Opentelemetry_Proto_Logs_V1_ResourceLogs]()
    resourceAndScopeMap.forEach { resMap in
      var scopeLogs = [Opentelemetry_Proto_Logs_V1_ScopeLogs]()
      resMap.value.forEach { scopeInfo, logRecords in
        var protoScopeLogs = Opentelemetry_Proto_Logs_V1_ScopeLogs()
        protoScopeLogs.scope = CommonAdapter.toProtoInstrumentationScope(instrumentationScopeInfo: scopeInfo)
        logRecords.forEach { record in
          protoScopeLogs.logRecords.append(record)
        }
        scopeLogs.append(protoScopeLogs)
      }
      var resourceLog = Opentelemetry_Proto_Logs_V1_ResourceLogs()
      resourceLog.resource = ResourceAdapter.toProtoResource(resource: resMap.key)
      resourceLog.scopeLogs.append(contentsOf: scopeLogs)
      resourceLogs.append(resourceLog)
    }
    return resourceLogs
  }
  
  static func groupByResourceAndScope(logRecordList: [ReadableLogRecord]) -> [Resource:[InstrumentationScopeInfo:[Opentelemetry_Proto_Logs_V1_LogRecord]]] {
    var result = [Resource:[InstrumentationScopeInfo: [Opentelemetry_Proto_Logs_V1_LogRecord]]]()
    logRecordList.forEach { logRecord in
      result[logRecord.resource, default:[InstrumentationScopeInfo: [Opentelemetry_Proto_Logs_V1_LogRecord]]()][logRecord.instrumentationScopeInfo,default:[Opentelemetry_Proto_Logs_V1_LogRecord]()].append(toProtoLogRecord(logRecord: logRecord))
    }
    return result
  }
  
  static func toProtoLogRecord(logRecord: ReadableLogRecord) -> Opentelemetry_Proto_Logs_V1_LogRecord {
    var protoLogRecord = Opentelemetry_Proto_Logs_V1_LogRecord()
    
    if let observedTimestamp = logRecord.observedTimestamp {
      protoLogRecord.observedTimeUnixNano = observedTimestamp.timeIntervalSince1970.toNanoseconds
    }
    
    protoLogRecord.timeUnixNano = logRecord.timestamp.timeIntervalSince1970.toNanoseconds
    
    if let body = logRecord.body {
      protoLogRecord.body = CommonAdapter.toProtoAnyValue(attributeValue: body)
    }
    
    
    if let severity = logRecord.severity {
      protoLogRecord.severityText = severity.description
      if let protoSeverity = Opentelemetry_Proto_Logs_V1_SeverityNumber(rawValue: severity.rawValue) {
        protoLogRecord.severityNumber = protoSeverity
      }
    }
    
    if let context = logRecord.spanContext {
      protoLogRecord.spanID = TraceProtoUtils.toProtoSpanId(spanId: context.spanId)
      protoLogRecord.traceID = TraceProtoUtils.toProtoTraceId(traceId: context.traceId)
      protoLogRecord.flags = UInt32(context.traceFlags.byte)
    }
    
    var protoAttributes = [Opentelemetry_Proto_Common_V1_KeyValue]()
    logRecord.attributes.forEach { key, value in
      protoAttributes.append(CommonAdapter.toProtoAttribute(key: key, attributeValue: value))
    }
    protoLogRecord.attributes = protoAttributes
    return protoLogRecord
  }
}
