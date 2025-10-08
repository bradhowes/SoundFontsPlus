// Copyright © 2025 Brad Howes. All rights reserved.

import AVKit
import Foundation

extension AVAudioSession: OutputVolumeStream {

  /**
   Obtain a stream of output volume changes for an AVAudioSession.

   - parameter onTermination: closure to call when the stream terminates
   - returns: 2-tuple containing a token for cancelling the observation and an AsyncStream of observed values
   */
  public func startStreamingOutputVolume() -> AsyncStream<AUValue> {
    startStreaming()
  }
}
