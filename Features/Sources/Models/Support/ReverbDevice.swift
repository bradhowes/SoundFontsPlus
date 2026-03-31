// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import BaseSupport
import Dependencies
import DependenciesMacros

public struct ReverbDevice: Sendable {
  public let effect: AVAudioUnitReverb?
  public let setConfig: @Sendable (AVAudioUnitReverb?, ReverbConfig.Draft) -> Void

  public init(
    effect: AVAudioUnitReverb?,
    setConfig: @Sendable @escaping (AVAudioUnitReverb?, ReverbConfig.Draft) -> Void,
  ) {
    self.effect = effect
    self.setConfig = setConfig
  }
}

extension ReverbDevice: DependencyKey {

  public static var liveValue: Self {
    return .init(
      effect: AVAudioUnitReverb(),
      setConfig: {
        log.info("setConfig - \($1, privacy: .public)")
        $0?.setConfig($1)
      }
    )
  }

  // TODO: use mocks for these to speed up tests
  public static let previewValue: Self = .init(effect: nil) { _, _ in }
  public static let testValue: Self = .init(effect: nil) { _, _ in }
}

private let log: Logger = .init(category: "ReverbDevice")
