import Foundation

#if (compiler(>=6) && os(Linux)) || OPENTELEMETRY_SWIFT_LINUX_COMPAT
  // https://github.com/open-telemetry/opentelemetry-swift/issues/615 prevents Linux builds from succeeding due to a regression in Swift 6 when subclassing Thread. We can work around this by using a block based Thread.
  class WorkerThread {
    var thread: Thread!

    var isCancelled: Bool {
      thread.isCancelled
    }

    init() {
      thread = Thread(block: { [weak self] in
        self?.main()
      })
    }

    func main() {}

    func start() {
      thread.start()
    }

    func cancel() {
      thread.cancel()
    }
  }
#else
  // Builds using a Swift older than 5 or on a non-Linux OS should be able to use the normal Thread subclass
  class WorkerThread: Thread {}
#endif
