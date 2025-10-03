import AVKit
import Foundation

/**
 Protocol for Swift/Obj-C entities that provide an `outputVolume` attribute that can be monitored with an
 `AsyncStream`.
 */
@objc public protocol OutputVolumeStream: AnyObject {
  typealias Observation = (NSKeyValueObservation, AsyncStream<AUValue>)

  @objc dynamic var outputVolume: AUValue { get }
}

extension OutputVolumeStream {

  /**
   Obtain a stream of volume changes for an object. Values will be emitted via an AsyncStream.

   ```
   (observerToken, stream) = outputVolumeProvider.startStreaming()
   for await value in stream {
     await send(.volumeChanged(value))
   }
   ```

   - parameter onTermination: closure to call when the stream terminates
   - returns: 2-tuple containing a token for cancelling the observation and an AsyncStream of observed values
   */

  public func start(onTermination: (@Sendable (Any) -> Void)? = nil) -> Observation where Self: NSObject & Sendable {
    let (stream, continuation) = AsyncStream<Float>.makeStream()
    let observerToken = self.observe(\.outputVolume, options: [.new]) { session, change  in
      var lastSeen: AUValue?
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

extension AVAudioSession: OutputVolumeStream {

  /**
   Obtain a stream of output volume changes for an AVAudioSession.

   - parameter onTermination: closure to call when the stream terminates
   - returns: 2-tuple containing a token for cancelling the observation and an AsyncStream of observed values
   */
  public func startStreamingOutputVolume(onTermination: (@Sendable (Any) -> Void)? = nil) -> OutputVolumeStream.Observation {
    start(onTermination: onTermination)
  }
}
