// Copyright © 2025 Brad Howes. All rights reserved.

@preconcurrency import AudioUnit.AUParameters
@preconcurrency import AVFAudio.AVAudioSession
import Dependencies
import DependenciesMacros

@DependencyClient
public struct OutputVolume: Sendable {
  public let getValue: @Sendable () -> AUValue
  public let startObserving: @Sendable () -> (NSKeyValueObservation, AsyncStream<Float>)
}

extension OutputVolume: DependencyKey {
  public static var liveValue: OutputVolume {
    .init(
      getValue: { AVAudioSession.sharedInstance().outputVolume },
      startObserving: { AVAudioSession.sharedInstance().startObservingOutputVolume() }
    )
  }
}

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

extension AUParameterTree: @retroactive TestDependencyKey {}

extension AUParameterTree: @retroactive DependencyKey {
  public static var liveValue: AUParameterTree { ParameterAddress.createParameterTree() }
  public static var previewValue: AUParameterTree { ParameterAddress.createParameterTree() }
  public static var testValue: AUParameterTree { ParameterAddress.createParameterTree() }
}

extension DependencyValues {

  public var outputVolume: OutputVolume {
    get { self[OutputVolume.self] }
    set { self[OutputVolume.self] = newValue }
  }

  public var delayDevice: DelayDevice {
    get { self[DelayDevice.self] }
    set { self[DelayDevice.self] = newValue }
  }

  public var reverbDevice: ReverbDevice {
    get { self[ReverbDevice.self] }
    set { self[ReverbDevice.self] = newValue }
  }

  public var parameters: AUParameterTree {
    get { self[AUParameterTree.self] }
    set { self[AUParameterTree.self] = newValue }
  }
}
