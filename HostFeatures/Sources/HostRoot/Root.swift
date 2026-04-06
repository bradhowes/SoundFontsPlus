// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import ComposableArchitecture
import HostAUv3s
import HostPresets
import HostSettings
import HostSupport
import SwiftUI
import TypedFullState

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

    public var auv3sList: AUv3sList.State
    public var presetsList: PresetsList.State
    public var songPlaying: Bool
    public let engine = AVAudioEngine()

    @ObservationStateIgnored
    public var outstandingInstanceCount: Int

    public init(instances: AUv3sList.State? = nil, presets: PresetsList.State? = nil) {
      @Shared(.auv3InstanceCount) var auv3InstanceCount
      self.auv3sList = instances ?? .init()
      self.presetsList = presets ?? .init()
      self.songPlaying = false
      self.outstandingInstanceCount = auv3InstanceCount
    }
  }

  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    case destination(PresentationAction<Destination.Action>)
    case initialize
    case auv3sList(AUv3sList.Action)
    case noteButtonTapped
    case playButtonTapped
    case presetsList(PresetsList.Action)
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Scope(state: \.auv3sList, action: \.auv3sList) { AUv3sList() }
    Scope(state: \.presetsList, action: \.presetsList) { PresetsList() }

    Reduce { state, action in
      switch action {

      case .binding: return .none
      case .destination(.presented(.settings(.delegate(.accepted)))): return reduce(into: &state, action: .auv3sList(.initialize))
      case .destination: return .none
      case .initialize: return initialize(&state)
      case .auv3sList(.delegate(.settingsButtonTapped)): return settingsButtonTapped(&state)
      case .auv3sList(.delegate(.added(instance: let instance))): return instanceCreated(&state, instance: instance)
      case .auv3sList(.delegate(.removed(instance: let instance))): return instanceRemoved(&state, instance: instance)
      case .auv3sList: return .none
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

  private func instanceCreated(_ state: inout State, instance: AUv3Instance) -> Effect<Action> {
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
      reduce(into: &state, action: .auv3sList(.initialize)),
      reduce(into: &state, action: .presetsList(.initialize))
    )
  }

  private func instanceRemoved(_ state: inout State, instance: AUv3Instance) -> Effect<Action> {
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
    return reduce(into: &state, action: .auv3sList(.playNote))
  }

  private func presetActivated(_ state: inout State, fullStates: TypedFullStateCollection) -> Effect<Action> {
    log.info("presetActivated BEGIN")
    guard state.outstandingInstanceCount <= 0 else { return .none }
    for index in 0..<max(fullStates.count, state.auv3sList.rows.count) {
      log.info("presetActivate - updating instance \(index)")
      if index < state.auv3sList.rows.count {
        let row = state.auv3sList.rows[index]
        let audioUnit = row.instance.audioUnit.auAudioUnit
        let typedFullState = index < fullStates.count ? fullStates[index] : nil
        log.info("presetActivated - before setting fullState - \(String(describing: typedFullState))")
        audioUnit.fullState = FullState.make(from: typedFullState)
        log.info("presetActivated - after setting fullState - audioUnitShortName: \(String(describing: audioUnit.audioUnitShortName))")
      } else {
        log.info("presetActivated - no instance for index \(index)")
      }
    }
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
    log.info("restoreActivePreset END")
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
    return reduce(into: &state, action: .auv3sList(.startLoops))
  }

  @discardableResult
  private func stopPlaying(_ state: inout State) -> Effect<Action> {
    if state.songPlaying == true {
      state.songPlaying = false
    }
    if state.engine.isRunning {
      state.engine.stop()
    }
    return reduce(into: &state, action: .auv3sList(.stopLoops))
  }

  private func updateActivePresetRequested(_ state: inout State) -> Effect<Action> {
    log.info("updateActivePresetRequested BEGIN")
    do {
      let fullStates: TypedFullStateCollection = try state.auv3sList.rows.map {
        try $0.instance.audioUnit.auAudioUnit.fullState?.asTypedAny()
      }
      log.info("updateActivePresetRequested END - \(fullStates)")
      return reduce(into: &state, action: .presetsList(.updateActivePreset(fullStates: fullStates)))
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
        AUv3sListView(store: store.scope(state: \.auv3sList, action: \.auv3sList))
        PresetsListView(store: store.scope(state: \.presetsList, action: \.presetsList))
      }
      Grid(horizontalSpacing: 16.0) {
        GridRow {
          Button {
            store.send(.playButtonTapped)
          } label: {
            Text(store.songPlaying ? "Stop Notes" : "Play Notes")
          }.disabled(store.auv3sList.rows.isEmpty)

          Button {
            store.send(.noteButtonTapped)
          } label: {
            Text("Instance Note")
          }.disabled(activeAUv3 == nil)
        }.frame(maxWidth: .infinity)
      }
      Group {
        if let activeAUv3,
           let index = store.auv3sList.rows.index(id: activeAUv3) {
          let instance = store.auv3sList.rows[index].instance
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
  prepareDependencies {
    $0.uuid = .incrementing
    $0.presetsStore = .previewValue
  }
  RootView.preview
}

#endif // DEBUG

private let log = Logger(category: "Root")
