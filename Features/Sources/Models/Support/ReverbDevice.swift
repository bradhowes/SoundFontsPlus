// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import BaseSupport
import Dependencies
import DependenciesMacros

@DependencyClient
public struct ReverbDevice: Sendable {
  public var setConfig: @Sendable (ReverbConfig.Draft) -> Void
  public var effect: @Sendable () -> AVAudioUnitReverb = { AVAudioUnitReverb() }
}

extension ReverbDevice: DependencyKey {
  public static var liveValue: ReverbDevice {
    let effect = AVAudioUnitReverb()
    return .init(
      setConfig: {
        log.info("setConfig - \($0, privacy: .public)")
        effect.setConfig($0)
      },
      effect: { effect }
    )
  }

  public static let previewValue: ReverbDevice = Self.liveValue
  public static let testValue: ReverbDevice = Self.liveValue
}

private let log: Logger = .init(category: "ReverbDevice")
