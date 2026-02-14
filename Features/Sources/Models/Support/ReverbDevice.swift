// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import BaseSupport
import Dependencies
import DependenciesMacros

public struct ReverbDevice: Sendable {
  public var setConfig: @Sendable (ReverbConfig.Draft) -> Void
  public var effect: @Sendable () -> AVAudioUnitReverb

  public init(
    setConfig: @Sendable @escaping (ReverbConfig.Draft) -> Void,
    effect: @Sendable @escaping () -> AVAudioUnitReverb
  ) {
    self.setConfig = setConfig
    self.effect = effect
  }
}

extension ReverbDevice: DependencyKey {

  public static var liveValue: Self {
    let effect = AVAudioUnitReverb()
    return .init(
      setConfig: {
        log.info("setConfig - \($0, privacy: .public)")
        effect.setConfig($0)
      },
      effect: { effect }
    )
  }

  // TODO: use mocks for these to speed up tests
  public static let previewValue: Self = Self.liveValue
  public static let testValue: Self = Self.liveValue
}

private let log: Logger = .init(category: "ReverbDevice")
