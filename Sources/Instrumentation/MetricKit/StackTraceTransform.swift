#if canImport(MetricKit) && !os(tvOS) && !os(macOS)
    import Foundation

    /// Transforms Apple's MetricKit stack trace format into the simplified OpenTelemetry format.
    /// See StackTraceFormat.md for details on the format specification.
    @available(iOS 14.0, macOS 12.0, macCatalyst 14.0, visionOS 1.0, *)
    func transformStackTrace(_ appleJsonData: Data) -> Data? {
        // Define structures for Apple's format
        struct AppleCallStackTree: Codable {
            let callStackTree: AppleCallStackTreeContent
        }

        struct AppleCallStackTreeContent: Codable {
            let callStackPerThread: Bool
            let callStacks: [AppleCallStack]
        }

        struct AppleCallStack: Codable {
            let threadAttributed: Bool?
            let callStackRootFrames: [AppleStackFrame]
        }

        struct AppleStackFrame: Codable {
            let binaryName: String
            let binaryUUID: String
            let offsetIntoBinaryTextSegment: Int
            let address: Int?
            let sampleCount: Int?
            let subFrames: [AppleStackFrame]?
        }

        // Define structures for our simplified format
        struct SimplifiedCallStackTree: Codable {
            let callStackPerThread: Bool
            let callStacks: [SimplifiedCallStack]
        }

        struct SimplifiedCallStack: Codable {
            let threadAttributed: Bool?
            let callStackFrames: [SimplifiedStackFrame]
        }

        struct SimplifiedStackFrame: Codable {
            let binaryName: String
            let binaryUUID: String
            let offsetAddress: Int
        }

        // Helper to recursively flatten a frame and its subframes
        func flattenFrames(_ frame: AppleStackFrame) -> [SimplifiedStackFrame] {
            var result: [SimplifiedStackFrame] = []

            // Add the current frame
            result.append(SimplifiedStackFrame(
                binaryName: frame.binaryName,
                binaryUUID: frame.binaryUUID,
                offsetAddress: frame.offsetIntoBinaryTextSegment
            ))

            // Recursively add subframes
            if let subFrames = frame.subFrames {
                for subFrame in subFrames {
                    result.append(contentsOf: flattenFrames(subFrame))
                }
            }

            return result
        }

        do {
            // Decode Apple's format. `MXCallStackTree.jsonRepresentation()` emits the tree
            // unwrapped; the `callStackTree` wrapper only appears when a whole
            // MXDiagnosticPayload is serialized. Accept both.
            let decoder = JSONDecoder()
            let appleTree = try (try? decoder.decode(AppleCallStackTreeContent.self, from: appleJsonData))
                ?? decoder.decode(AppleCallStackTree.self, from: appleJsonData).callStackTree

            // Transform to simplified format
            let simplifiedCallStacks = appleTree.callStacks.map { appleStack in
                // Flatten all root frames and their subframes
                let allFrames = appleStack.callStackRootFrames.flatMap { flattenFrames($0) }

                return SimplifiedCallStack(
                    threadAttributed: appleStack.threadAttributed,
                    callStackFrames: allFrames
                )
            }

            let simplifiedTree = SimplifiedCallStackTree(
                callStackPerThread: appleTree.callStackPerThread,
                callStacks: simplifiedCallStacks
            )

            // Encode to JSON
            let encoder = JSONEncoder()
            return try encoder.encode(simplifiedTree)
        } catch {
            // If transformation fails, return nil and the caller will use the original format
            return nil
        }
    }
#endif
