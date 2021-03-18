/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation
import OpenTelemetrySdk
import OpenTelemetryApi

internal class TaskInterception {
    /// An identifier uniquely identifying the task interception across all `URLSessions`.
    internal let identifier: UUID
    /// The initial request send during this interception. It is, the request send from `URLSession`, not the one
    /// given by the user (as the request could have been modified in `URLSessionSwizzler`).
    internal let request: URLRequest
    /// Tells if the `request` is send to a 1st party host.
    internal let isFirstPartyRequest: Bool
    /// Task metrics collected during this interception.
    private(set) var metrics: ResourceMetrics?
    /// Task completion collected during this interception.
    private(set) var completion: ResourceCompletion?
    /// Trace information propagated with the task. Not available when Tracing is disabled
    /// or when the task was created through `URLSession.dataTask(with:url)` on some iOS13+.
    private(set) var spanContext: SpanContext?

    init(request: URLRequest, isFirstParty: Bool) {
        self.identifier = UUID()
        self.request = request
        self.isFirstPartyRequest = isFirstParty
    }

    func register(metrics: ResourceMetrics) {
        self.metrics = metrics
    }

    func register(completion: ResourceCompletion) {
        self.completion = completion
    }

    func register(spanContext: SpanContext) {
        self.spanContext = spanContext
    }

    /// Tells if the interception is done (mean: both metrics and completion were collected).
    var isDone: Bool {
        metrics != nil && completion != nil
    }
}

internal struct ResourceCompletion {
    let httpResponse: HTTPURLResponse?
    let error: Error?

    init(response: URLResponse?, error: Error?) {
        self.httpResponse = response as? HTTPURLResponse
        self.error = error
    }
}

/// Encapsulates key metrics retrieved from `URLSessionTaskMetrics`.
/// Reference: https://developer.apple.com/documentation/foundation/urlsessiontasktransactionmetrics
internal struct ResourceMetrics {
    struct DateInterval {
        let start, end: Date
        var duration: TimeInterval { end.timeIntervalSince(start) }
    }

    /// Properties of the fetch phase for the resource:
    /// - `start` -  the time when the task started fetching the resource from the server,
    /// - `end` - the time immediately after the task received the last byte of the resource.
    let fetch: DateInterval

    /// Properties of the redirection phase for the resource. If the resource is retrieved in multiple transactions,
    /// only the last one is used to track detailed metrics (`dns`, `connect` etc.).
    /// All but last are described as a single "redirection" phase.
    let redirection: DateInterval?

    /// Properties of the name lookup phase for the resource.
    let dns: DateInterval?

    /// Properties of the connect phase for the resource.
    let connect: DateInterval?

    /// Properties of the secure connect phase for the resource.
    let ssl: DateInterval?

    /// Properties of the TTFB phase for the resource.
    let firstByte: DateInterval?

    /// Properties of the download phase for the resource.
    let download: DateInterval?

    /// The size of data delivered to delegate or completion handler.
    let responseSize: Int64?
}

extension ResourceMetrics {
    init(taskMetrics: URLSessionTaskMetrics) {
        let fetch = DateInterval(
            start: taskMetrics.taskInterval.start,
            end: taskMetrics.taskInterval.end
        )

        let transactions = taskMetrics.transactionMetrics
            .filter { $0.resourceFetchType != .localCache } // ignore loads from cache

        // Note: `transactions` contain metrics for each individual
        // `request → response` transaction done for given resource, e.g.:
        // * if `200 OK` was received, it will contain 1 transaction,
        // * if `200 OK` was preceeded by `301` redirection, it will contain 2 transactions.
        let mainTransaction = transactions.last
        let redirectionTransactions = transactions.dropLast()

        var redirection: DateInterval? = nil

        if redirectionTransactions.count > 0 {
            let redirectionStarts = redirectionTransactions.compactMap { $0.fetchStartDate }
            let redirectionEnds = redirectionTransactions.compactMap { $0.responseEndDate }

            // If several redirections were made, we model them as a single "redirection"
            // phase starting in the first moment of the youngest and ending
            // in the last moment of the oldest.
            if let redirectionPhaseStart = redirectionStarts.first,
               let redirectionPhaseEnd = redirectionEnds.last {
                redirection = DateInterval(start: redirectionPhaseStart, end: redirectionPhaseEnd)
            }
        }

        var dns: DateInterval? = nil
        var connect: DateInterval? = nil
        var ssl: DateInterval? = nil
        var firstByte: DateInterval? = nil
        var download: DateInterval? = nil
        var responseSize: Int64? = nil

        if let mainTransaction = mainTransaction {
            if let dnsStart = mainTransaction.domainLookupStartDate,
               let dnsEnd = mainTransaction.domainLookupEndDate {
                dns = DateInterval(start: dnsStart, end: dnsEnd)
            }

            if let connectStart = mainTransaction.connectStartDate,
               let connectEnd = mainTransaction.connectEndDate {
                connect = DateInterval(start: connectStart, end: connectEnd)
            }

            if let sslStart = mainTransaction.secureConnectionStartDate,
               let sslEnd = mainTransaction.secureConnectionEndDate {
                ssl = DateInterval(start: sslStart, end: sslEnd)
            }

            if let firstByteStart = mainTransaction.requestStartDate, // Time from start requesting the resource ...
               let firstByteEnd = mainTransaction.responseStartDate { // ... to receiving the first byte of the response
                firstByte = DateInterval(start: firstByteStart, end: firstByteEnd)
            }

            if let downloadStart = mainTransaction.responseStartDate, // Time from the first byte of the response ...
               let downloadEnd = mainTransaction.responseEndDate {    // ... to receiving the last byte.
                download = DateInterval(start: downloadStart, end: downloadEnd)
            }

            if #available(iOS 13.0, *), #available(macOS 10.15, *), #available(tvOS 13.0, *), #available(watchOS 6.0, *){
                responseSize = mainTransaction.countOfResponseBodyBytesAfterDecoding
            }
        }

        self.init(
            fetch: fetch,
            redirection: redirection,
            dns: dns,
            connect: connect,
            ssl: ssl,
            firstByte: firstByte,
            download: download,
            responseSize: responseSize
        )
    }
}
