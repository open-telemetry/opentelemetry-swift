/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

/// Struct to access a set of pre-defined Samplers.
public enum Samplers {
  /// A Sampler that always makes a "yes" decision on Span sampling.
  public static var alwaysOn: Sampler = AlwaysOnSampler()
  ///  Sampler that always makes a "no" decision on Span sampling.
  public static var alwaysOff: Sampler = AlwaysOffSampler()
  /// Returns a new TraceIdRatioBased Sampler. The probability of sampling a trace is equal to that
  /// of the specified probability.
  /// - Parameter probability: The desired probability of sampling. Must be within [0.0, 1.0].
  public static func traceIdRatio(ratio: Double) -> Sampler {
    return TraceIdRatioBased(ratio: ratio)
  }

  /// Returns a new ParentBased Sampler. The probability of sampling a trace is equal to that
  /// of the specified probability.
  /// - Parameter probability: The desired probability of sampling. Must be within [0.0, 1.0].
  public static func parentBased(
    root: Sampler,
    remoteParentSampled: Sampler? = nil,
    remoteParentNotSampled: Sampler? = nil,
    localParentSampled: Sampler? = nil,
    localParentNotSampled: Sampler? = nil
  ) -> Sampler {
    return ParentBasedSampler(
      root: root,
      remoteParentSampled: remoteParentSampled,
      remoteParentNotSampled: remoteParentNotSampled,
      localParentSampled: localParentSampled,
      localParentNotSampled: localParentNotSampled)
  }

  static var alwaysOnDecision: Decision = SimpleDecision(decision: true)
  static var alwaysOffDecision: Decision = SimpleDecision(decision: false)
}

class AlwaysOnSampler: Sampler {
  func shouldSample(
    parentContext: SpanContext?,
    traceId: TraceId,
    name: String,
    kind: SpanKind,
    attributes: [String: AttributeValue],
    parentLinks: [SpanData.Link]
  ) -> Decision {
    return Samplers.alwaysOnDecision
  }

  var description: String {
    return "AlwaysOnSampler"
  }
}

class AlwaysOffSampler: Sampler {
  func shouldSample(
    parentContext: SpanContext?,
    traceId: TraceId,
    name: String,
    kind: SpanKind,
    attributes: [String: AttributeValue],
    parentLinks: [SpanData.Link]
  ) -> Decision {
    return Samplers.alwaysOffDecision
  }

  var description: String {
    return "AlwaysOffSampler"
  }
}

/// We assume the lower 64 bits of the traceId's are randomly distributed around the whole (long)
/// range. We convert an incoming probability into an upper bound on that value, such that we can
/// just compare the absolute value of the id and the bound to see if we are within the desired
/// probability range. Using the low bits of the traceId also ensures that systems that only use 64
/// bit ID's will also work with this sampler.
class TraceIdRatioBased: Sampler {
  var probability: Double
  var idUpperBound: UInt

  init(ratio: Double) {
    self.probability = ratio
    if ratio <= 0.0 {
      idUpperBound = UInt.min
    } else if ratio >= 1.0 {
      idUpperBound = UInt.max
    } else {
      idUpperBound = UInt(ratio * Double(UInt.max))
    }
  }

  func shouldSample(
    parentContext: SpanContext?,
    traceId: TraceId,
    name: String,
    kind: SpanKind,
    attributes: [String: AttributeValue],
    parentLinks: [SpanData.Link]
  ) -> Decision {
    /// If the parent is sampled keep the sampling decision.
    if parentContext?.traceFlags.sampled ?? false {
      return Samplers.alwaysOnDecision
    }

    for link in parentLinks where link.context.traceFlags.sampled {
      return Samplers.alwaysOnDecision
    }
    /// Always sample if we are within probability range. This is true even for child spans (that
    /// may have had a different sampling decision made) to allow for different sampling policies,
    /// and dynamic increases to sampling probabilities for debugging purposes.
    /// Note use of `<` for comparison. This ensures that we never sample for probability == 0.0
    /// while allowing for a (very) small chance of *not* sampling if the id == Long.MAX_VALUE.
    /// This is considered a reasonable tradeoff for the simplicity/performance requirements (this
    /// code is executed in-line for every Span creation).
    if traceId.rawLowerLong < idUpperBound {
      return Samplers.alwaysOnDecision
    } else {
      return Samplers.alwaysOffDecision
    }
  }

  var description: String {
    return String(format: "TraceIdRatioBased{%.6f}", probability)
  }
}

/// A Sampler that uses the sampled flag of the parent Span, if present. If the span has no parent,
/// this Sampler will use the "root" sampler that it is built with.
class ParentBasedSampler: Sampler {
  private let root: Sampler
  private let remoteParentSampled: Sampler
  private let remoteParentNotSampled: Sampler
  private let localParentSampled: Sampler
  private let localParentNotSampled: Sampler

  internal init(
    root: Sampler,
    remoteParentSampled: Sampler? = nil,
    remoteParentNotSampled: Sampler? = nil,
    localParentSampled: Sampler? = nil,
    localParentNotSampled: Sampler? = nil
  ) {
    self.root = root
    self.remoteParentSampled = remoteParentSampled ?? Samplers.alwaysOn
    self.remoteParentNotSampled = remoteParentNotSampled ?? Samplers.alwaysOff
    self.localParentSampled = localParentSampled ?? Samplers.alwaysOn
    self.localParentNotSampled = localParentNotSampled ?? Samplers.alwaysOff
  }

  /// If a parent is set, always follows the same sampling decision as the parent.
  /// Otherwise, uses the delegateSampler provided at initialization to make a decision.
  func shouldSample(
    parentContext: SpanContext?,
    traceId: TraceId,
    name: String,
    kind: SpanKind,
    attributes: [String: AttributeValue],
    parentLinks: [SpanData.Link]
  ) -> Decision {
    guard let parentSpanContext = parentContext, parentSpanContext.isValid
    else {
      return root.shouldSample(
        parentContext: parentContext, traceId: traceId, name: name, kind: kind,
        attributes: attributes, parentLinks: parentLinks)
    }

    if parentSpanContext.isRemote {
      return parentSpanContext.isSampled
        ? remoteParentSampled.shouldSample(
          parentContext: parentContext, traceId: traceId, name: name,
          kind: kind, attributes: attributes, parentLinks: parentLinks)
        : remoteParentNotSampled.shouldSample(
          parentContext: parentContext, traceId: traceId, name: name,
          kind: kind, attributes: attributes, parentLinks: parentLinks)
    }
    return parentSpanContext.isSampled
      ? localParentSampled.shouldSample(
        parentContext: parentContext, traceId: traceId, name: name, kind: kind,
        attributes: attributes, parentLinks: parentLinks)
      : localParentNotSampled.shouldSample(
        parentContext: parentContext, traceId: traceId, name: name, kind: kind,
        attributes: attributes, parentLinks: parentLinks)
  }

  var description: String {
    return
      "ParentBasedSampler{root:\(root), remoteParentSampled:\(remoteParentSampled) remoteParentNotSampled:\(remoteParentNotSampled) localParentSampled:\(localParentSampled) localParentNotSampled:\(localParentNotSampled)}"
  }
}

/// Sampling decision without attributes.
private struct SimpleDecision: Decision {
  let decision: Bool

  /// Creates sampling decision without attributes.
  /// - Parameter decision: sampling decision
  init(decision: Bool) {
    self.decision = decision
  }

  public var isSampled: Bool {
    return decision
  }

  public var attributes: [String: AttributeValue] {
    return [String: AttributeValue]()
  }
}
