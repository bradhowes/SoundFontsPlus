// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import BaseSupport
import Dependencies
import DependenciesMacros

/**
 A ReverbDevice provides a dependency interface for the reverb effect. The only requirement of the interface is
 that it support a `setConfig` method which must call the `setConfig` method defined on the `AVAudioUnitReverb`.
 */
public struct ReverbDevice: Sendable {
  public let effect: AVAudioUnitReverb?
  @usableFromInline
  let setConfig: @Sendable (AVAudioUnitReverb?, ReverbConfig.Draft) -> Void

  public init(
    effect: AVAudioUnitReverb?,
    setConfig: @Sendable @escaping (AVAudioUnitReverb?, ReverbConfig.Draft) -> Void,
  ) {
    self.effect = effect
    self.setConfig = setConfig
  }

  @inlinable
  public func setConfig(_ config: ReverbConfig.Draft) {
    setConfig(effect, config)
  }
}

extension ReverbDevice: TestDependencyKey {

  public static var liveValue: Self {
    return .init(
      effect: AVAudioUnitReverb(),
      setConfig: {
        log.info("setConfig - \($1, privacy: .public)")
        $0?.setConfig($1)
      }
    )
  }

  public static var previewValue: Self { .init(effect: nil) { _, _ in } }
  public static var testValue: Self { .init(effect: nil) { _, _ in } }
}

private let log: Logger = .init(category: "ReverbDevice")
