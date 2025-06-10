// Copyright © 2025 Brad Howes. All rights reserved.

import AudioUnit
import AVFoundation
import AUv3Controls
import ComposableArchitecture
import SharingGRDB
import SwiftUI

extension AVAudioUnitReverbPreset: @retroactive Identifiable {
  public var id: Int { rawValue }

  static let allCases: [AVAudioUnitReverbPreset] = [
    .smallRoom,
    .mediumRoom,
    .largeRoom,
    .largeRoom2,
    .mediumHall,
    .mediumHall2,
    .mediumHall3,
    .largeHall,
    .largeHall2,
    .mediumChamber,
    .largeChamber,
    .cathedral,
    .plate
  ]

  public var name: String {
    switch self {
    case .smallRoom: return "Room 1"
    case .mediumRoom: return "Room 2"
    case .largeRoom: return "Room 3"
    case .largeRoom2: return "Room 4"
    case .mediumHall: return "Hall 1"
    case .mediumHall2: return "Hall 2"
    case .mediumHall3: return "Hall 3"
    case .largeHall: return "Hall 4"
    case .largeHall2: return "Hall 5"
    case .mediumChamber: return "Chamber 1"
    case .largeChamber: return "Chamber 2"
    case .cathedral: return "Cathedral"
    case .plate: return "Plate"
    @unknown default:
      fatalError()
    }
  }
}

@Reducer
public struct ReverbFeature {
  let parameters: AUParameterTree

  public init(parameters: AUParameterTree) {
    self.parameters = parameters
  }

  public var state: State { .init(parameters: self.parameters) }

  @ObservableState
  public struct State: Equatable {
    public var enabled: ToggleFeature.State
    public var locked: ToggleFeature.State
    public var wetDryMix: KnobFeature.State
    public var room: AVAudioUnitReverbPreset

    public var reverbConfigId: ReverbConfig.ID?

    public init(parameters: AUParameterTree) {
      self.enabled = .init(isOn: false, displayName: "On")
      self.locked = .init(isOn: false, displayName: "Locked")
      self.wetDryMix = .init(parameter: parameters[.delayWetDryMix])
      self.room = .mediumChamber
    }
  }

  @Dependency(\.defaultDatabase) private var database
  @Dependency(\.reverb) private var reverb
  @Shared(.activeState) private var activeState

  public enum Action {
    case debouncedSave(ReverbConfig.Draft)
    case debouncedUpdate(ReverbConfig.Draft)
    case enabled(ToggleFeature.Action)
    case locked(ToggleFeature.Action)
    case room(AVAudioUnitReverbPreset)
    case wetDryMix(KnobFeature.Action)
  }

  private enum CancelID {
    case debouncedSave
    case debouncedUpdate
  }

  public var body: some ReducerOf<Self> {

    Scope(state: \.enabled, action: \.enabled) { ToggleFeature() }
    Scope(state: \.locked, action: \.locked) { ToggleFeature() }
    Scope(state: \.wetDryMix, action: \.wetDryMix) { KnobFeature(parameter: parameters[.reverbWetDryMix]) }

    Reduce { state, action in
      switch action {
      case let .debouncedSave(config):
        reverb.setConfig(config)
        return .none

      case let .debouncedUpdate(config):
        if config.id != nil {
          withErrorReporting {
            try database.write { db in
              try ReverbConfig.upsert(config).execute(db)
            }
          }
        }
        return .none

      case .enabled: return updateReverb(&state)
      case .locked: return .none
      case let .room(value): return changeRoom(&state, room: value)
      case .wetDryMix: return updateReverb(&state)
      }
    }
  }

  private func changeRoom(_ state: inout State, room: AVAudioUnitReverbPreset) -> Effect<Action> {
    state.room = room
    return updateReverb(&state)
  }

  private func updateReverb(_ state: inout State) -> Effect<Action> {
    let _ = ReverbConfig.Draft(
      id: state.reverbConfigId,
      preset: state.room.rawValue,
      wetDryMix: state.wetDryMix.value / 100.0,
      enabled: state.enabled.isOn
    )

    return .none
//    return .merge(
//      .run { send in
//        try await Task.sleep(for: .milliseconds(300))
//        await send(.debouncedUpdate(config))
//      }.cancellable(id: CancelID.debouncedUpdate),
//      .run { send in
//        try await Task.sleep(for: .milliseconds(500))
//        await send(.debouncedSave(config))
//      }.cancellable(id: CancelID.debouncedSave)
//    )
  }
}

public struct ReverbView: View {
  @Bindable private var store: StoreOf<ReverbFeature>
  @Environment(\.auv3ControlsTheme) var theme

  public init(store: StoreOf<ReverbFeature>) {
    self.store = store
  }

  public var body: some View {
    EffectsContainer(
      enabled: store.enabled.isOn,
      title: "Reverb",
      onOff: ToggleView(store: store.scope(state: \.enabled, action: \.enabled)),
      globalLock: ToggleView(store: store.scope(state: \.locked, action: \.locked)) {
        Image(systemName: "lock")
      }
    ) {
      HStack(alignment: .center, spacing: 8) {
        Picker("Room", selection: $store.room.sending(\.room)) {
          ForEach(AVAudioUnitReverbPreset.allCases, id: \.self) { room in
            Text(room.name).tag(room)
              .font(theme.font)
              .foregroundStyle(theme.textColor)
          }
        }
        .pickerStyle(.wheel)
        .frame(width: 110)  // !!! Magic size that fits all of the strings without wasted space
        KnobView(store: store.scope(state: \.wetDryMix, action: \.wetDryMix))
      }
    }
  }
}

extension ReverbView {
  static var preview: some View {
    var theme = Theme()
    theme.controlTrackStrokeStyle = StrokeStyle(lineWidth: 5, lineCap: .round)
    theme.controlValueStrokeStyle = StrokeStyle(lineWidth: 3, lineCap: .round)
    theme.toggleOnIndicatorSystemName = "arrowtriangle.down.fill"
    theme.toggleOffIndicatorSystemName = "arrowtriangle.down"

    let parameterTree = ParameterAddress.createParameterTree()
    let _ = prepareDependencies {
      $0.defaultDatabase = try! appDatabase()
    }
    return ScrollView(.horizontal) {
      ReverbView(store: Store(initialState: .init(parameters: parameterTree)) {
        ReverbFeature(parameters: parameterTree)
      })
      .environment(\.auv3ControlsTheme, theme)
    }
    .padding()
    .border(theme.controlBackgroundColor, width: 1)
  }
}

#Preview {
  ReverbView.preview
}
