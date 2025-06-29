import AudioUnit.AUParameters
import Dependencies

public struct DelayDevice {
  public var getConfig: @Sendable () -> DelayConfig.Draft
  public var setConfig: @Sendable (DelayConfig.Draft) -> Void
}

extension DelayDevice: DependencyKey {
  public static var liveValue: DelayDevice {
    .init(
      getConfig: { unimplemented("DelayDevice.getConfig", placeholder: DelayConfig.Draft()) },
      setConfig: { _ in unimplemented("DelayDevice.setConfig") }
    )
  }

  public static var previewValue: DelayDevice {
    .init(
      getConfig: { unimplemented("DelayDevice.getConfig", placeholder: DelayConfig.Draft()) },
      setConfig: { _ in unimplemented("DelayDevice.setConfig") }
    )
  }

  public static var testValue: DelayDevice {
    .init(
      getConfig: { unimplemented("DelayDevice.getConfig", placeholder: DelayConfig.Draft()) },
      setConfig: { _ in unimplemented("DelayDevice.setConfig") }
    )
  }
}

public struct ReverbDevice: Sendable {
  public var getConfig: @Sendable () -> ReverbConfig.Draft
  public var setConfig: @Sendable (ReverbConfig.Draft) -> Void
}

extension ReverbDevice: DependencyKey {
  public static var liveValue: ReverbDevice {
    .init(
      getConfig: { unimplemented("ReverbDevice.getConfig", placeholder: ReverbConfig.Draft()) },
      setConfig: { _ in unimplemented("ReverbDevice.setConfig") }
    )
  }

  public static var previewValue: ReverbDevice {
    .init(
      getConfig: { unimplemented("ReverbDevice.getConfig", placeholder: ReverbConfig.Draft()) },
      setConfig: { _ in unimplemented("ReverbDevice.setConfig") }
    )
  }

  public static var testValue: ReverbDevice {
    .init(
      getConfig: { unimplemented("ReverbDevice.getConfig", placeholder: ReverbConfig.Draft()) },
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
