// Copyright © 2025 Brad Howes. All rights reserved.

public import BaseSupport
import Foundation

/// A mock of AVAudioSession.outputVolume that toggles between 1.0 and 0.0
final public class OutputVolumeFlipFlop: @unchecked Sendable {
  public var continuation: AsyncStream<Float>.Continuation?
  public var currentValue: Float = 1.0

  public func getValue() -> Float { self.currentValue }

  /**
   Toggle current value and emit onto the stream.

   - returns: new value
   */
  @discardableResult public func advance() -> Float {
    self.currentValue = 1.0 - self.currentValue
    continuation?.yield(self.currentValue)
    return self.currentValue
  }

  public func startStreaming() -> AsyncStream<Float> {
    AsyncStream<Float> { self.continuation = $0 }
  }

  /**
   Obtain an `OutputVolume` instance that relies on this instance for operation.

   - returns: current value
   */
  public func makeOutputVolume() -> OutputVolume {
    .init(
      getValue: { self.getValue() },
      startStreaming: { self.startStreaming() }
    )
  }

  public init() {}
}
