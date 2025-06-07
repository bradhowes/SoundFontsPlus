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

  @ObservableState
  public struct State: Equatable {
    public var enabled: ToggleFeature.State
    public var locked: ToggleFeature.State
    public var wetDryMix: KnobFeature.State
    public var room: AVAudioUnitReverbPreset

    public var reverbConfigId: ReverbConfig.ID?

    public init() {
      self.enabled = .init(isOn: false, displayName: "On")
      self.locked = .init(isOn: false, displayName: "Locked")
      self.wetDryMix = .init(
        value: 50.0,
        displayName: "Mix",
        minimumValue: 0.0,
        maximumValue: 100.0,
        logarithmic: false
      )
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

  public init() {}
  
  public var body: some ReducerOf<Self> {

    Scope(state: \.enabled, action: \.enabled) { ToggleFeature() }
    Scope(state: \.locked, action: \.locked) { ToggleFeature() }
    Scope(state: \.wetDryMix, action: \.wetDryMix) { KnobFeature() }

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
    let config = ReverbConfig.Draft(
      id: state.reverbConfigId,
      preset: state.room.rawValue,
      wetDryMix: state.wetDryMix.value / 100.0,
      enabled: state.enabled.isOn
    )

    return .merge(
      .run { send in
        try await Task.sleep(for: .milliseconds(300))
        await send(.debouncedUpdate(config))
      }.cancellable(id: CancelID.debouncedUpdate),
      .run { send in
        try await Task.sleep(for: .milliseconds(500))
        await send(.debouncedSave(config))
      }.cancellable(id: CancelID.debouncedSave)
    )
  }
}

public struct ReverbView: View {
  @Bindable private var store: StoreOf<ReverbFeature>
  @Environment(\.auv3ControlsTheme) var theme

  public init(store: StoreOf<ReverbFeature>) {
    self.store = store
  }

  public var body: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 18) {
        Text("Reverb")
          .foregroundStyle(theme.controlForegroundColor)
          .font(.caption.smallCaps())
        ToggleView(store: store.scope(state: \.enabled, action: \.enabled))
        ToggleView(store: store.scope(state: \.locked, action: \.locked)) {
          Image(systemName: "lock")
        }
      }
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
        .disabled(!store.enabled.isOn)
        KnobView(store: store.scope(state: \.wetDryMix, action: \.wetDryMix))
          .disabled(!store.enabled.isOn)
      }
      .padding(.init(top: 16, leading: 0, bottom: 0, trailing: 0))
      .dimmedAppearanceModifier(enabled: store.enabled.isOn)
    }
    .padding(.init(top: 4, leading: 4, bottom: 4, trailing: 4))
  }
}

extension ReverbView {
  static var preview: some View {
    var theme = Theme()
    theme.controlTrackStrokeStyle = StrokeStyle(lineWidth: 5, lineCap: .round)
    theme.controlValueStrokeStyle = StrokeStyle(lineWidth: 3, lineCap: .round)
    theme.toggleOnIndicatorSystemName = "arrowtriangle.down.fill"
    theme.toggleOffIndicatorSystemName = "arrowtriangle.down"
    let _ = prepareDependencies {
      $0.defaultDatabase = try! appDatabase()
    }
    return ScrollView(.horizontal) {
      ReverbView(store: Store(initialState: .init()) { ReverbFeature() })
        .environment(\.auv3ControlsTheme, theme)
    }
    .frame(height: 102)
    .frame(maxHeight: 102)
  }
}

#Preview {
  ReverbView.preview
}
