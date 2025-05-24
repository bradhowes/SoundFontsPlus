// Copyright © 2025 Brad Howes. All rights reserved.

import AudioUnit
import AVFoundation
import AUv3Controls
import ComposableArchitecture
import Sharing
import SwiftUI

extension AVAudioUnitReverbPreset: @retroactive Identifiable {
  public var id: Int { rawValue }

  static let allCases: [AVAudioUnitReverbPreset] = [
    AVAudioUnitReverbPreset.smallRoom,
    AVAudioUnitReverbPreset.mediumRoom,
    AVAudioUnitReverbPreset.largeRoom,
    AVAudioUnitReverbPreset.largeRoom2,
    AVAudioUnitReverbPreset.mediumHall,
    AVAudioUnitReverbPreset.mediumHall2,
    AVAudioUnitReverbPreset.mediumHall3,
    AVAudioUnitReverbPreset.largeHall,
    AVAudioUnitReverbPreset.largeHall2,
    AVAudioUnitReverbPreset.mediumChamber,
    AVAudioUnitReverbPreset.largeChamber,
    AVAudioUnitReverbPreset.cathedral,
    AVAudioUnitReverbPreset.plate
  ]

  public var name: String {
    switch self {
    case .smallRoom: return "Small Room"
    case .mediumRoom: return "Medium Room"
    case .largeRoom: return "Large Room 1"
    case .largeRoom2: return "Large Room 2"
    case .mediumHall: return "Medium Hall 1"
    case .mediumHall2: return "Medium Hall 2"
    case .mediumHall3: return "Medium Hall 3"
    case .largeHall: return "Large Hall 1"
    case .largeHall2: return "Large Hall 2"
    case .mediumChamber: return "Medium Chamber"
    case .largeChamber: return "Large Chamber"
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

  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    case enabled(ToggleFeature.Action)
    case locked(ToggleFeature.Action)
    case room(AVAudioUnitReverbPreset)
    case wetDryMix(KnobFeature.Action)
  }
  
  public init() {}
  
  public var body: some ReducerOf<Self> {
    BindingReducer()

    Scope(state: \.enabled, action: \.enabled) { ToggleFeature() }
    Scope(state: \.locked, action: \.locked) { ToggleFeature() }
    Scope(state: \.wetDryMix, action: \.wetDryMix) { KnobFeature() }

    Reduce { state, action in
      switch action {
      case .binding: return .none
      case .enabled: return .none
      case .locked: return .none
      case let .room(value):
        state.room = value
        return .none
      case .wetDryMix: return .none
      }
    }
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
      HStack(alignment: .center, spacing: 16) {
        Picker("Room", selection: $store.room) {
          ForEach(AVAudioUnitReverbPreset.allCases, id: \.self) { room in
            Text(room.name).tag(room)
              .font(theme.font)
              .foregroundStyle(theme.textColor)
          }
        }
        .pickerStyle(.wheel)
        .frame(width: 165)  // !!! Magic size that fits all of the strings without wasted space
//        VStack {
//          Text("Room")
//          Menu("\(store.room.name)") {
//            ForEach(AVAudioUnitReverbPreset.allCases) { room in
//              Button(room.name) {
//                store.send(.room(room))
//              }
//              .font(theme.font)
//              .foregroundStyle(theme.textColor)
//            }
//          }
//          .font(theme.font)
//          .foregroundStyle(theme.textColor)
//        }
        KnobView(store: store.scope(state: \.wetDryMix, action: \.wetDryMix))
      }
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
