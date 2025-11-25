// Copyright © 2025 Brad Howes. All rights reserved.

import AVKit
import Foundation

private let log = Logger(category: "OutputVolumeStream")

/**
 Protocol for Swift/Obj-C entities that provide an `outputVolume` attribute that can be monitored with an
 `AsyncStream`.
 */
@objc public protocol OutputVolumeStream: AnyObject {
  @objc dynamic var outputVolume: AUValue { get }
}

extension OutputVolumeStream {

  /**
   Obtain a stream of volume changes for an object. Values will be emitted via an AsyncStream.

   ```
   stream = outputVolumeProvider.startStreaming()
   for await value in stream {
   await send(.volumeChanged(value))
   }
   ```

   - returns: an AsyncStream of observed values
   */
  public func startStreaming() -> AsyncStream<AUValue> where Self: NSObject & Sendable {
    log.info("startStreaming")
    return .init { continuation in
      log.info("start closure")
      let observerToken = self.observe(\.outputVolume, options: [.new]) { _, change  in
        if let newValue = change.newValue {
          log.info("new volume value: \(newValue)")
          continuation.yield(newValue)
        }
      }
      continuation.onTermination = { _ in
        log.info("stream terminated")
        observerToken.invalidate()
      }
    }
  }
}
