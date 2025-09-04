import AVKit
import Foundation

extension AVAudioSession {

  public typealias Observation = (NSKeyValueObservation, AsyncStream<Float>)

  /**
   Obtain a stream of volume changes for an AVAudioSession.

   - returns: 2-tuple containing a token for cancelling the observation and an AsyncStream of observed values
   */
  public func startObservingOutputVolume(onTermination: (@Sendable (Any) -> Void)? = nil) -> Observation {
    let (stream, continuation) = AsyncStream<Float>.makeStream()
    let observerToken = self.observe(\.outputVolume, options: [.new]) { session, change  in
      var lastSeen: Float?
      if self == session,
         let newValue = change.newValue,
         newValue != lastSeen {
        lastSeen = newValue
        continuation.yield(newValue)
      }
    }

    continuation.onTermination = onTermination
    return (observerToken, stream)
  }
}

final class OutputVolumeFlipFlop: @unchecked Sendable {
  var continuation: AsyncStream<Float>.Continuation?
  var currentValue: Float = 1.0

  func getValue() -> Float { self.currentValue }

  func startObserving() -> (NSKeyValueObservation?, AsyncStream<Float>) {
    let stream = AsyncStream { continuation in
      self.continuation = continuation
    }
    return (nil, stream)
  }

  @discardableResult
  func advance() -> Float {
    self.currentValue = 1.0 - self.currentValue
    continuation?.yield(self.currentValue)
    return self.currentValue
  }

  func outputVolume() -> OutputVolume {
    .init(
      getValue: { self.getValue() },
      startObserving: { self.startObserving() }
    )
  }
}
