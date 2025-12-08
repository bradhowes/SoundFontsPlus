// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import Dependencies
import DependenciesMacros
import Foundation

#if os(iOS)

@DependencyClient
public struct OutputVolume: Sendable {
  public let getValue: @Sendable () -> AUValue
  public let startStreaming: @Sendable () -> AsyncStream<Float>

  public init(
    getValue: @escaping @Sendable () -> AUValue,
    startStreaming: @escaping @Sendable () -> AsyncStream<Float>
  ) {
    self.getValue = getValue
    self.startStreaming = startStreaming
  }
}

extension OutputVolume: DependencyKey {
  public static var liveValue: OutputVolume {
    .init(
      getValue: { AVAudioSession.sharedInstance().outputVolume },
      startStreaming: { AVAudioSession.sharedInstance().startStreamingOutputVolume() }
    )
  }
}

#endif
