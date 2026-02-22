// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import ComposableArchitecture
import HostAUv3s
import HostPresets
import HostSettings
import HostSupport
import SwiftUI

@Reducer
public struct Root {

  public static func prepareDependencies(subtype: String, manufacturer: String) {
    @Shared(.componentSubtype) var componentSubtype
    $componentSubtype.withLock { $0 = subtype }
    @Shared(.componentManufacturer) var componentManufacturer
    $componentManufacturer.withLock { $0 = manufacturer }
    Dependencies.prepareDependencies {
      $0.componentDescription = .liveValue
      $0.presetsStore = .liveValue
    }
  }

  @Reducer
  public enum Destination {
    case settings(Settings)
  }

  @ObservableState
  public struct State: Equatable {
    @Presents public var destination: Destination.State?

    public var instances: AUv3sList.State
    public var presets: PresetsList.State
    public var songPlaying: Bool
    public let engine = AVAudioEngine()

    public init(instances: AUv3sList.State? = nil, presets: PresetsList.State? = nil) {
      self.instances = instances ?? .init()
      self.presets = presets ?? .init()
      self.songPlaying = false
    }
  }

  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    case destination(PresentationAction<Destination.Action>)
    case initialize
    case instances(AUv3sList.Action)
    case noteButtonTapped
    case playButtonTapped
    case presets(PresetsList.Action)
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Scope(state: \.instances, action: \.instances) { AUv3sList() }
    Scope(state: \.presets, action: \.presets) { PresetsList() }

    Reduce { state, action in
      switch action {

      case .binding:
        return .none

      case .destination(.presented(.settings(.delegate(.accepted)))):
        return reduce(into: &state, action: .instances(.initialize))

      case .destination:
        return .none

      case .initialize:
        return initialize(&state)

      case .instances(.delegate(.settings)):
        state.destination = .settings(.init())
        return .none

      case .instances(.delegate(.added(instance: let instance))):
        return addInstance(&state, instance: instance)

      case .instances(.delegate(.removed(instance: let instance))):
        return removeInstance(&state, instance: instance)

      case .instances:
        return .none

      case .noteButtonTapped:
        return playNote(&state)

      case .playButtonTapped:
        return playButtonTapped(&state)

      case .presets:
        return .none
      }
    }
    .ifLet(\.$destination, action: \.destination)
  }

  private enum CancelId {
    case playLoop
  }
}

extension Root {

  private func addInstance(_ state: inout State, instance: AUv3Instance) -> Effect<Action> {
    log.info("addInstance BEGIN")
    stopPlaying(&state)
    state.engine.attach(instance.audioUnit)
    state.engine.connect(instance.audioUnit, to: state.engine.mainMixerNode, format: AudioSession.audioFormat)
    log.info("addInstance END")
    return .none
  }

  private func initialize(_ state: inout State) -> Effect<Action> {
    state.engine.connect(state.engine.mainMixerNode, to: state.engine.outputNode, format: AudioSession.audioFormat)
    return .none
  }

  private func playButtonTapped(_ state: inout State) -> Effect<Action> {
    state.songPlaying ? stopPlaying(&state) : startPlaying(&state)
  }

  private func playNote(_ state: inout State) -> Effect<Action> {
    updateAudioSession(active: true)
    startEngine(&state)
    return reduce(into: &state, action: .instances(.playNote))
  }

  private func removeInstance(_ state: inout State, instance: AUv3Instance) -> Effect<Action> {
    stopPlaying(&state)
    state.engine.disconnectNodeOutput(instance.audioUnit)
    state.engine.detach(instance.audioUnit)
    return .none
  }

  @discardableResult
  private func startEngine(_ state: inout State) -> Effect<Action> {
    guard !state.engine.isRunning else { return .none }
    do {
      try state.engine.start()
      log.info("engine started")
    } catch {
      fatalError("Failed to start engine - \(error)")
    }
    return .none
  }

  private func startPlaying(_ state: inout State) -> Effect<Action> {
    updateAudioSession(active: true)
    startEngine(&state)
    state.songPlaying = true
    return reduce(into: &state, action: .instances(.startLoops))
  }

  @discardableResult
  private func stopPlaying(_ state: inout State) -> Effect<Action> {
    if state.songPlaying == true {
      state.songPlaying = false
    }
    if state.engine.isRunning {
      state.engine.stop()
    }
    return reduce(into: &state, action: .instances(.stopLoops))
  }

  private func updateAudioSession(active: Bool) {
#if os(iOS)
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.playback, mode: .default)
      try session.setActive(active)
    } catch {
      fatalError("Could not set Audio Session active \(active). error: \(error).")
    }
#endif
  }
}

extension Root.Destination.State: Equatable {}

public struct RootView: View {
  @Bindable private var store: StoreOf<Root>
  @Shared(.activeAUv3) var activeAUv3

  public init(store: StoreOf<Root>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: 16) {
      HStack(spacing: 16) {
        AUv3sListView(store: store.scope(state: \.instances, action: \.instances))
        PresetsListView(store: store.scope(state: \.presets, action: \.presets))
      }
      Grid(horizontalSpacing: 16.0) {
        GridRow {
          Button {
            store.send(.playButtonTapped)
          } label: {
            Text(store.songPlaying ? "Stop Notes" : "Play Notes")
          }.disabled(store.instances.rows.isEmpty)

          Button {
            store.send(.noteButtonTapped)
          } label: {
            Text("Instance Note")
          }.disabled(activeAUv3 == nil)
        }.frame(maxWidth: .infinity)
      }
      Group {
        if let activeAUv3,
           let index = store.instances.rows.index(id: activeAUv3) {
          let instance = store.instances.rows[index].instance
          ZStack {
            Color.black
            AUv3View(instance: instance)
              .id(instance.id)
              .preferredColorScheme(.dark)
          }
        } else {
          Text("No AUv3 instance selected")
            .frame(maxHeight: .infinity)
        }
      }
    }
    .task {
      await store.send(.initialize).finish()
    }
    .sheet(item: $store.scope(state: \.destination?.settings, action: \.destination.settings)) {
      SettingsView(store: $0)
    }
  }
}

#if DEBUG

extension RootView {

  static var preview: some View {
    prepareDependencies {
      $0.uuid = .incrementing
      $0.presetsStore = .previewValue
      return RootView(
        store: Store(initialState: .init(instances: AUv3sList.State(), presets: PresetsList.State())) {
          Root()
        }
      ).safeAreaPadding(16)
    }
  }
}

#Preview {
  RootView.preview
}

#endif // DEBUG

private let log = Logger(category: "Root")
