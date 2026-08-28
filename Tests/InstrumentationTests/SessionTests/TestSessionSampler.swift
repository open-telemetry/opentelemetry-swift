import Foundation
@testable import Sessions

final class TestSessionSampler: SessionSampler, @unchecked Sendable {
  private let lock = NSLock()
  private var decisions: [SessionSamplingDecision]
  private var sampledIds: [String] = []

  init(decisions: [SessionSamplingDecision]) {
    self.decisions = decisions
  }

  func samplingDecision(for sessionId: String) -> SessionSamplingDecision {
    return lock.withLock {
      sampledIds.append(sessionId)
      guard !decisions.isEmpty else { return .sampled }
      return decisions.removeFirst()
    }
  }

  var callCount: Int {
    return lock.withLock { sampledIds.count }
  }

  var sessionIds: [String] {
    return lock.withLock { sampledIds }
  }
}
