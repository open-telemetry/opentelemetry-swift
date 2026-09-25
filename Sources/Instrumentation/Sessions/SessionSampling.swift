/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

/// A sampling decision shared by every signal produced during one session.
public enum SessionSamplingDecision: String, Codable, Sendable {
  /// Record telemetry associated with the session.
  case sampled
  /// Do not record telemetry associated with the session.
  case notSampled

  /// Whether signal integrations should record telemetry for the session.
  public var isSampled: Bool {
    return self == .sampled
  }
}

/// Makes one sampling decision when a session is created.
public protocol SessionSampler: Sendable {
  /// Returns the decision for a newly generated session identifier.
  ///
  /// The callback runs without a session-manager or persistence lock held. Other callers that need
  /// the new session wait for this decision so telemetry is not assigned to a partially initialized
  /// session. Implementations should return promptly, must not perform network or other unbounded
  /// work, and must not call session APIs that create or reset sessions. Telemetry emitted directly
  /// by this callback cannot carry the new session decision because it does not exist yet.
  func samplingDecision(for sessionId: String) -> SessionSamplingDecision
}

/// Samples every session.
public struct AlwaysOnSessionSampler: SessionSampler {
  public init() {}

  public func samplingDecision(for sessionId: String) -> SessionSamplingDecision {
    return .sampled
  }
}

/// Samples no sessions.
public struct AlwaysOffSessionSampler: SessionSampler {
  public init() {}

  public func samplingDecision(for sessionId: String) -> SessionSamplingDecision {
    return .notSampled
  }
}
