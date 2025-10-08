import AVFAudio
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct OutputVolume: Sendable {
  public let getValue: @Sendable () -> AUValue
  public let startStreaming: @Sendable () -> AsyncStream<Float>
}

extension OutputVolume: DependencyKey {
  public static var liveValue: OutputVolume {
    .init(
      getValue: { AVAudioSession.sharedInstance().outputVolume },
      startStreaming: { AVAudioSession.sharedInstance().startStreamingOutputVolume() }
    )
  }
}
