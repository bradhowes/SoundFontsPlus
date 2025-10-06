// Copyright © 2025 Brad Howes. All rights reserved.

import AudioUnit.AUParameters
import AVFAudio.AVAudioSession
import Dependencies
import DependenciesMacros
import Models

@DependencyClient
public struct ReverbDevice: Sendable {
  public var setConfig: @Sendable (ReverbConfig.Draft) -> Void
}

extension ReverbDevice: DependencyKey {
  public static var liveValue: ReverbDevice {
    .init(
      setConfig: { _ in unimplemented("ReverbDevice.setConfig") }
    )
  }

  public static var previewValue: ReverbDevice {
    .init(
      setConfig: { _ in unimplemented("ReverbDevice.setConfig") }
    )
  }

  public static var testValue: ReverbDevice {
    .init(
      setConfig: { _ in unimplemented("ReverbDevice.setConfig") }
    )
  }
}

extension DependencyValues {

  public var reverbDevice: ReverbDevice {
    get { self[ReverbDevice.self] }
    set { self[ReverbDevice.self] = newValue }
  }
}
