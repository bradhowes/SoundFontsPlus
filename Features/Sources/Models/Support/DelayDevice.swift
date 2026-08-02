// Copyright © 2025 Brad Howes. All rights reserved.

public import AVFAudio.AVAudioUnitDelay
import BaseSupport
public import Dependencies
import DependenciesMacros

/**
 A DelayDevice provides a dependency interface for the delay effect. The only requirement of the interface is
 that it support a `setConfig` method which must call the `setConfig` method defined on the `AVAudioUnitDelay`.
 */
public struct DelayDevice: Sendable {
  public let effect: AVAudioUnitDelay?
  @usableFromInline
  var setConfig: @Sendable (AVAudioUnitDelay?, DelayConfig.Draft) -> Void

  public init(
    effect: AVAudioUnitDelay?,
    setConfig: @Sendable @escaping (AVAudioUnitDelay?, DelayConfig.Draft) -> Void
  ) {
    self.effect = effect
    self.setConfig = setConfig
  }

  @inlinable
  public func setConfig(_ config: DelayConfig.Draft) {
    setConfig(effect, config)
  }
}

extension DelayDevice: DependencyKey {

  public static let liveValue: Self = .init(
    effect: AVAudioUnitDelay(),
    setConfig: {
      log.info("setConfig - \($1, privacy: .public)")
      $0?.setConfig($1)
    }
  )

  public static let previewValue: Self = .init(effect: nil, setConfig: { _, _ in })
  public static let testValue: Self = .init(effect: nil, setConfig: { _, _ in })
}

private let log: Logger = .init(category: "DelayDevice")
