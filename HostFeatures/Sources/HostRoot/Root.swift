// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import ComposableArchitecture
import HostPresets
import HostSettings
import HostSupport
import HostSynths
import OSLog
import SwiftUI
import TypedFullState

@Reducer
public struct Root {

  @MainActor
  public static func makeWithDependencies(subtype: String, manufacturer: String) -> StoreOf<Root> {
    @Shared(.componentSubtype) var componentSubtype
    $componentSubtype.withLock { $0 = subtype }
    @Shared(.componentManufacturer) var componentManufacturer
    $componentManufacturer.withLock { $0 = manufacturer }
    Dependencies.prepareDependencies {
      $0.componentDescription = .liveValue
      $0.presetsStore = .liveValue
    }

    return .init(initialState: .init()) {
      Root()
    }
  }

  @Reducer
  public enum Destination {
    case settings(Settings)
  }

  @ObservableState
  public struct State: Equatable {
    @Presents public var destination: Destination.State?

    public var synthsList: SynthsList.State
    public var presetsList: PresetsList.State
    public var songPlaying: Bool
    public let engine = AVAudioEngine()

    @ObservationStateIgnored
    public var outstandingInstanceCount: Int

    public init(instances: SynthsList.State? = nil, presets: PresetsList.State? = nil) {
      @Shared(.auv3InstanceCount) var auv3InstanceCount
      self.synthsList = instances ?? .init()
      self.presetsList = presets ?? .init()
      self.songPlaying = false
      self.outstandingInstanceCount = auv3InstanceCount
    }
  }

  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    case destination(PresentationAction<Destination.Action>)
    case initialize
    case synthsList(SynthsList.Action)
    case noteButtonTapped
    case playButtonTapped
    case presetsList(PresetsList.Action)
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Scope(state: \.synthsList, action: \.synthsList) { SynthsList() }
    Scope(state: \.presetsList, action: \.presetsList) { PresetsList() }

    Reduce { state, action in
      switch action {

      case .binding: return .none
      case .destination(.presented(.settings(.delegate(.configurationChanged)))): return .send(.synthsList(.initialize))
      case .destination: return .none
      case .initialize: return initialize(&state)
      case .synthsList(.delegate(.settingsButtonTapped)): return settingsButtonTapped(&state)
      case .synthsList(.delegate(.added(instance: let instance))): return instanceCreated(&state, instance: instance)
      case .synthsList(.delegate(.removed(instance: let instance))): return instanceRemoved(&state, instance: instance)
      case .synthsList: return .none
      case .noteButtonTapped: return playNote(&state)
      case .playButtonTapped: return playButtonTapped(&state)
      case .presetsList(.delegate(.presetActivated(let fullStates))): return presetActivated(&state, fullStates: fullStates)
      case .presetsList(.delegate(.updateActivePresetRequested)): return updateActivePresetRequested(&state)
      case .presetsList: return .none
      }
    }
    .ifLet(\.$destination, action: \.destination)
  }

  private enum CancelId {
    case playLoop
  }
}

extension Root {

  private func instanceCreated(_ state: inout State, instance: SynthInstance) -> Effect<Action> {
    log.info("instanceCreated BEGIN")
    stopPlaying(&state)
    state.engine.attach(instance.audioUnit)
    state.engine.connect(instance.audioUnit, to: state.engine.mainMixerNode, format: AudioSession.audioFormat)
    state.outstandingInstanceCount -= 1

    if state.outstandingInstanceCount == 0 {
      return restoreActivePreset(&state)
    }
    log.info("instanceCreated END")
    return .none
  }

  private func initialize(_ state: inout State) -> Effect<Action> {
    state.engine.connect(state.engine.mainMixerNode, to: state.engine.outputNode, format: AudioSession.audioFormat)
    return .merge(
      .send(.synthsList(.initialize)),
      .send(.presetsList(.initialize))
    )
  }

  private func instanceRemoved(_ state: inout State, instance: SynthInstance) -> Effect<Action> {
    stopPlaying(&state)
    state.engine.disconnectNodeOutput(instance.audioUnit)
    state.engine.detach(instance.audioUnit)
    return .none
  }

  private func playButtonTapped(_ state: inout State) -> Effect<Action> {
    state.songPlaying ? stopPlaying(&state) : startPlaying(&state)
  }

  private func playNote(_ state: inout State) -> Effect<Action> {
    updateAudioSession(active: true)
    startEngine(&state)
    return .send(.synthsList(.playNote))
  }

  private func presetActivated(_ state: inout State, fullStates: TypedFullStateCollection) -> Effect<Action> {
    log.info("presetActivated BEGIN - fullStates count: \(fullStates.count)")
    guard state.outstandingInstanceCount <= 0 else {
      log.info("presetActivated END - pending instances")
      return .none
    }

    for index in 0..<min(fullStates.count, state.synthsList.rows.count) {
      log.info("presetActivate - updating instance \(index)")
      let row = state.synthsList.rows[index]
      let audioUnit = row.instance.audioUnit.auAudioUnit
      let typedFullState = index < fullStates.count ? fullStates[index] : nil
      log.info("presetActivated - before setting fullState - \(String(describing: typedFullState))")
      audioUnit.fullState = FullState.make(from: typedFullState)
      log.info("presetActivated - after setting fullState - audioUnitShortName: \(String(describing: audioUnit.audioUnitShortName))")
    }

    log.info("presetActivated END")
    return .none
  }

  private func restoreActivePreset(_ state: inout State) -> Effect<Action> {
    log.info("restoreActivePreset BEGIN")
    @Shared(.activePreset) var activePreset
    guard
      let activePreset,
      let index = state.presetsList.rows.index(id: activePreset)
    else {
      log.info("restoreActivePreset END - cannot restore active preset")
      return .none
    }

    let fullStates = state.presetsList.rows[index].preset.fullStateCollection
    return presetActivated(&state, fullStates: fullStates)
  }

  private func settingsButtonTapped(_ state: inout State) -> Effect<Action> {
    state.destination = .settings(.init())
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
    return .send(.synthsList(.startLoops))
  }

  @discardableResult
  private func stopPlaying(_ state: inout State) -> Effect<Action> {
    if state.songPlaying == true {
      state.songPlaying = false
    }
    if state.engine.isRunning {
      state.engine.stop()
    }
    return .send(.synthsList(.stopLoops))
  }

  private func updateActivePresetRequested(_ state: inout State) -> Effect<Action> {
    log.info("updateActivePresetRequested BEGIN")
    do {
      let fullStates: TypedFullStateCollection = try state.synthsList.rows.map {
        try $0.instance.audioUnit.auAudioUnit.fullState?.asTypedAny()
      }
      log.info("updateActivePresetRequested END - \(fullStates)")
      return .send(.presetsList(.updateActivePreset(fullStates: fullStates)))
    } catch {
      log.error("updateActivePresetRequested - failed: \(error.localizedDescription)")
    }

    log.info("updateActivePresetRequested END")
    return .none
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
        AUv3sListView(store: store.scope(state: \.synthsList, action: \.synthsList))
        PresetsListView(store: store.scope(state: \.presetsList, action: \.presetsList))
      }
      HStack(spacing: 32) {
        Text("AUv3 View")
          .bold()
        HStack(spacing: 16) {
          Button {
            store.send(.playButtonTapped)
          } label: {
            Text(store.songPlaying ? "Stop Notes" : "Play Notes")
          }
          .disabled(store.synthsList.rows.isEmpty)

          Button {
            store.send(.noteButtonTapped)
          } label: {
            Text("Instance Note")
          }
          .disabled(activeAUv3 == nil)
        }
        .buttonStyle(.bordered)
      }

      Group {
        if let activeAUv3,
           let index = store.synthsList.rows.index(id: activeAUv3) {
          let instance = store.synthsList.rows[index].instance
          AUv3View(instance: instance)
            .id(instance.id)
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
    RootView(
      store: Store(initialState: .init(instances: SynthsList.State(), presets: PresetsList.State())) {
        Root()
      }
    ).safeAreaPadding(16)
  }
}

#Preview {
  // swiftlint:disable:next
  let _ = prepareDependencies {
    $0.uuid = .incrementing
    $0.presetsStore = .previewValue
  }
  RootView.preview
}

#endif // DEBUG

private let log = Logger(category: "Root")
