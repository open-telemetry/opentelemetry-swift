/**
 * Autogenerated by Thrift Compiler (0.13.0)
 *
 * DO NOT EDIT UNLESS YOU ARE SURE THAT YOU KNOW WHAT YOU ARE DOING
 *  @generated
 */

#if !os(watchOS)

  import Foundation

  import Thrift

  private final class Agent_emitZipkinBatch_args {
    fileprivate var spans: TList<Span>

    fileprivate init(spans: TList<Span>) {
      self.spans = spans
    }
  }

  private func == (lhs: Agent_emitZipkinBatch_args, rhs: Agent_emitZipkinBatch_args) -> Bool {
    return
      lhs.spans == rhs.spans
  }

  extension Agent_emitZipkinBatch_args: Hashable {
    func hash(into hasher: inout Hasher) {
      hasher.combine(spans)
    }
  }

  extension Agent_emitZipkinBatch_args: TStruct {
    fileprivate static var fieldIds: [String: Int32] {
      return ["spans": 1]
    }

    fileprivate static var structName: String {
      return "Agent_emitZipkinBatch_args"
    }

    fileprivate static func read(from proto: TProtocol) throws
      -> Agent_emitZipkinBatch_args {
      _ = try proto.readStructBegin()
      var spans: TList<Span>!

      fields: while true {
        let (_, fieldType, fieldID) = try proto.readFieldBegin()

        switch (fieldID, fieldType) {
        case (_, .stop): break fields
        case (1, .list): spans = try TList<Span>.read(from: proto)
        case let (_, unknownType): try proto.skip(type: unknownType)
        }

        try proto.readFieldEnd()
      }

      try proto.readStructEnd()
      // Required fields
      try proto.validateValue(spans, named: "spans")

      return Agent_emitZipkinBatch_args(spans: spans)
    }
  }

  private final class Agent_emitBatch_args {
    fileprivate var batch: Batch

    fileprivate init(batch: Batch) {
      self.batch = batch
    }
  }

  private func == (lhs: Agent_emitBatch_args, rhs: Agent_emitBatch_args) -> Bool {
    return lhs.batch == rhs.batch
  }

  extension Agent_emitBatch_args: Hashable {
    func hash(into hasher: inout Hasher) {
      hasher.combine(batch)
    }
  }

  extension Agent_emitBatch_args: TStruct {
    fileprivate static var fieldIds: [String: Int32] {
      return ["batch": 1]
    }

    fileprivate static var structName: String { return "Agent_emitBatch_args" }

    fileprivate static func read(from proto: TProtocol) throws
      -> Agent_emitBatch_args {
      _ = try proto.readStructBegin()
      var batch: Batch!

      fields: while true {
        let (_, fieldType, fieldID) = try proto.readFieldBegin()

        switch (fieldID, fieldType) {
        case (_, .stop): break fields
        case (1, .struct): batch = try Batch.read(from: proto)
        case let (_, unknownType): try proto.skip(type: unknownType)
        }

        try proto.readFieldEnd()
      }

      try proto.readStructEnd()
      // Required fields
      try proto.validateValue(batch, named: "batch")

      return Agent_emitBatch_args(batch: batch)
    }
  }

  extension AgentClient: Agent {
    private func send_emitZipkinBatch(spans: TList<Span>) throws {
      try outProtocol.writeMessageBegin(name: "emitZipkinBatch", type: .oneway, sequenceID: 0)
      let args = Agent_emitZipkinBatch_args(spans: spans)
      try args.write(to: outProtocol)
      try outProtocol.writeMessageEnd()
    }

    public func emitZipkinBatch(spans: TList<Span>) throws {
      try send_emitZipkinBatch(spans: spans)
      try outProtocol.transport.flush()
    }

    private func send_emitBatch(batch: Batch) throws {
      try outProtocol.writeMessageBegin(name: "emitBatch", type: .oneway, sequenceID: 0)
      let args = Agent_emitBatch_args(batch: batch)
      try args.write(to: outProtocol)
      try outProtocol.writeMessageEnd()
    }

    public func emitBatch(batch: Batch) throws {
      try send_emitBatch(batch: batch)
      try outProtocol.transport.flush()
    }
  }

  extension AgentAsyncClient: AgentAsync {
    private func send_emitZipkinBatch(on outProtocol: TProtocol, spans: TList<Span>) throws {
      try outProtocol.writeMessageBegin(name: "emitZipkinBatch", type: .oneway, sequenceID: 0)
      let args = Agent_emitZipkinBatch_args(spans: spans)
      try args.write(to: outProtocol)
      try outProtocol.writeMessageEnd()
    }

    public func emitZipkinBatch(spans: TList<Span>, completion: @escaping (TAsyncResult<Void>) -> Void) {
      let transport = factory.newTransport()
      let proto = Protocol(on: transport)

      do {
        try send_emitZipkinBatch(on: proto, spans: spans)
      } catch let error {
        completion(.error(error))
      }

      transport.flush { _, error in
        if let error = error {
          completion(.error(error))
        }
        completion(.success(Void()))
      }
    }

    private func send_emitBatch(on outProtocol: TProtocol, batch: Batch) throws {
      try outProtocol.writeMessageBegin(name: "emitBatch", type: .oneway, sequenceID: 0)
      let args = Agent_emitBatch_args(batch: batch)
      try args.write(to: outProtocol)
      try outProtocol.writeMessageEnd()
    }

    public func emitBatch(batch: Batch, completion: @escaping (TAsyncResult<Void>) -> Void) {
      let transport = factory.newTransport()
      let proto = Protocol(on: transport)

      do {
        try send_emitBatch(on: proto, batch: batch)
      } catch let error {
        completion(.error(error))
      }

      transport.flush { _, error in

        if let error = error {
          completion(.error(error))
        }
        completion(.success(Void()))
      }
    }
  }

  extension AgentProcessor: TProcessor {
    static let processorHandlers: ProcessorHandlerDictionary = {
      var processorHandlers = ProcessorHandlerDictionary()

      processorHandlers["emitZipkinBatch"] = { _, inProtocol, _, _ in

        let args = try Agent_emitZipkinBatch_args.read(from: inProtocol)

        try inProtocol.readMessageEnd()
      }
      processorHandlers["emitBatch"] = { _, inProtocol, _, _ in

        let args = try Agent_emitBatch_args.read(from: inProtocol)

        try inProtocol.readMessageEnd()
      }
      return processorHandlers
    }()

    public func process(on inProtocol: TProtocol, outProtocol: TProtocol) throws {
      let (messageName, _, sequenceID) = try inProtocol.readMessageBegin()
      if let processorHandler = AgentProcessor.processorHandlers[messageName] {
        do {
          try processorHandler(sequenceID, inProtocol, outProtocol, service)
        } catch let error as TApplicationError {
          try outProtocol.writeException(messageName: messageName, sequenceID: sequenceID, ex: error)
        }
      } else {
        try inProtocol.skip(type: .struct)
        try inProtocol.readMessageEnd()
        let ex = TApplicationError(
          error: .unknownMethod(methodName: messageName))
        try outProtocol.writeException(messageName: messageName, sequenceID: sequenceID, ex: ex)
      }
    }
  }

#endif
