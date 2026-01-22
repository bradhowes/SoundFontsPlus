// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import Dependencies
import DependenciesMacros

@DependencyClient
public struct DelayDevice: Sendable {
  public var setConfig: @Sendable (DelayConfig.Draft) -> Void
  public var effect: @Sendable () -> AVAudioUnitDelay = { AVAudioUnitDelay() }
}

extension DelayDevice: DependencyKey {
  public static var liveValue: DelayDevice {
    let effect = AVAudioUnitDelay()
    return .init(
      setConfig: { effect.setConfig($0) },
      effect: { effect }
    )
  }

  public static let previewValue: DelayDevice = Self.liveValue
  public static let testValue: DelayDevice = Self.liveValue
}
