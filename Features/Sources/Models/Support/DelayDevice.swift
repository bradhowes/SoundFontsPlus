// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import BaseSupport
import Dependencies
import DependenciesMacros

public struct DelayDevice: Sendable {
  public var setConfig: @Sendable (DelayConfig.Draft) -> Void
  public var effect: @Sendable () -> AVAudioUnitDelay

  public init(
    setConfig: @Sendable @escaping (DelayConfig.Draft) -> Void,
    effect: @Sendable @escaping () -> AVAudioUnitDelay
  ) {
    self.setConfig = setConfig
    self.effect = effect
  }
}

extension DelayDevice: DependencyKey {

  public static var liveValue: DelayDevice {
    let effect = AVAudioUnitDelay()
    return .init(
      setConfig: {
        log.info("setConfig - \($0, privacy: .public)")
        effect.setConfig($0)
      },
      effect: { effect }
    )
  }

  // TODO: use mocks for these to speed up tests
  public static let previewValue: DelayDevice = Self.liveValue
  public static let testValue: DelayDevice = Self.liveValue
}

private let log: Logger = .init(category: "DelayDevice")
