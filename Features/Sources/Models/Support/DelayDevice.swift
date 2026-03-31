// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import BaseSupport
import Dependencies
import DependenciesMacros

public struct DelayDevice: Sendable {
  public let effect: AVAudioUnitDelay?
  public var setConfig: @Sendable (AVAudioUnitDelay?, DelayConfig.Draft) -> Void

  public init(
    effect: AVAudioUnitDelay?,
    setConfig: @Sendable @escaping (AVAudioUnitDelay?, DelayConfig.Draft) -> Void
  ) {
    self.effect = effect
    self.setConfig = setConfig
  }
}

extension DelayDevice: DependencyKey {

  public static var liveValue: Self {
    return .init(
      effect: AVAudioUnitDelay(),
      setConfig: {
        log.info("setConfig - \($1, privacy: .public)")
        $0?.setConfig($1)
      }
    )
  }

  // TODO: use mocks for these to speed up tests
  public static let previewValue: Self = .init(effect: nil, setConfig: { _, _ in })
  public static let testValue: Self = .init(effect: nil, setConfig: { _, _ in })
}

private let log: Logger = .init(category: "DelayDevice")
