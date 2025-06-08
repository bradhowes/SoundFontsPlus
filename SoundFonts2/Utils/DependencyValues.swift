import AudioUnit.AUParameters
import Dependencies

public struct DelayConfigurable: Sendable {
  public var setConfig: @Sendable (DelayConfig.Draft) -> Void
}

extension DelayConfigurable: DependencyKey {
  public static var liveValue: DelayConfigurable { .init(setConfig: { _ in unimplemented("setConfig") } ) }
  public static var previewValue: DelayConfigurable { .init(setConfig: { _ in unimplemented("setConfig") } ) }
  public static var testValue: DelayConfigurable { .init(setConfig: { _ in unimplemented("setConfig") } ) }
}

public struct ReverbConfigurable: Sendable {
  public var setConfig: @Sendable (ReverbConfig.Draft) -> Void
}

extension ReverbConfigurable: DependencyKey {
  public static var liveValue: ReverbConfigurable { .init(setConfig: { _ in unimplemented("setConfig") } ) }
  public static var previewValue: ReverbConfigurable { .init(setConfig: { _ in unimplemented("setConfig") } ) }
  public static var testValue: ReverbConfigurable { .init(setConfig: { _ in unimplemented("setConfig") } ) }
}

extension AUParameterTree: @retroactive TestDependencyKey {}

extension AUParameterTree: @retroactive DependencyKey {
  public static var liveValue: AUParameterTree { ParameterAddress.createParameterTree() }
  public static var previewValue: AUParameterTree { ParameterAddress.createParameterTree() }
  public static var testValue: AUParameterTree { ParameterAddress.createParameterTree() }
}

extension DependencyValues {

  public var delay: DelayConfigurable {
    get { self[DelayConfigurable.self] }
    set { self[DelayConfigurable.self] = newValue }
  }

  public var reverb: ReverbConfigurable {
    get { self[ReverbConfigurable.self] }
    set { self[ReverbConfigurable.self] = newValue }
  }

  public var parameters: AUParameterTree {
    get { self[AUParameterTree.self] }
    set { self[AUParameterTree.self] = newValue }
  }
}
