// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio.AVAudioUnitDelay
import Dependencies
import DependenciesMacros
import Models

@DependencyClient
public struct DelayDevice: Sendable {
  public var setConfig: @Sendable (DelayConfig.Draft) -> Void
}

extension DelayDevice: DependencyKey {
  public static var liveValue: DelayDevice {
    .init(
      setConfig: { _ in unimplemented("DelayDevice.setConfig") }
    )
  }

  public static var previewValue: DelayDevice {
    .init(
      setConfig: { _ in unimplemented("DelayDevice.setConfig") }
    )
  }

  public static var testValue: DelayDevice {
    .init(
      setConfig: { _ in unimplemented("DelayDevice.setConfig") }
    )
  }
}

extension DependencyValues {

  public var delayDevice: DelayDevice {
    get { self[DelayDevice.self] }
    set { self[DelayDevice.self] = newValue }
  }
}


extension AVAudioUnitDelay {

  public func setConfig(_ config: DelayConfig.Draft) {

  }
}
