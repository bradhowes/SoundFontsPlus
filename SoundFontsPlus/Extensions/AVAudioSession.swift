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
