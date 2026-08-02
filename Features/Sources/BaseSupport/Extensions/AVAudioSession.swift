// Copyright © 2025 Brad Howes. All rights reserved.

public import AVFAudio
import Foundation

#if os(iOS)

extension AVAudioSession: OutputVolumeStream {

  /**
   Obtain a stream of output volume changes for an AVAudioSession.

   - returns: 2-tuple containing a token for cancelling the observation and an AsyncStream of observed values
   */
  public func startStreamingOutputVolume() -> AsyncStream<AUValue> {
    startStreaming()
  }
}

#endif // os(iOS)
