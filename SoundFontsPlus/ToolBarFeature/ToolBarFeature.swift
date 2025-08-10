// Copyright © 2025 Brad Howes. All rights reserved.

import AUv3Controls
import Combine
import ComposableArchitecture
import Dependencies
import Sharing
import SwiftUI

@Reducer
public struct ToolBarFeature {

  @Reducer
  public enum Destination {
    case settings(SettingsFeature)
  }

  @ObservableState
  public struct State {
    @Presents var destination: Destination.State?

    public enum TrafficKind {
      case accepted
      case blocked

      var color: Color {
        switch self {
        case .accepted: return .accentColor
        case .blocked: return .orange
        }
      }
    }

    let midiMonitor: MIDIMonitor?
    var lowestKey: Note
    var highestKey: Note

    @Shared(.keyboardSlides) var keyboardSlides

    var tagsListVisible: Bool
    var effectsVisible: Bool

    var editingPresetVisibility: Bool = false
    var showMoreButtons: Bool = false
    var preset: Preset?

    var showTrafficColor: Color = .clear
    var showTrafficPublisher: PassthroughSubject<Void, Never> = .init()

    public init(tagsListVisible: Bool, effectsVisible: Bool, midiMonitor: MIDIMonitor? = nil) {
      @Shared(.firstVisibleKey) var firstVisibleKey: Note
      self.midiMonitor = midiMonitor
      self.tagsListVisible = tagsListVisible
      self.effectsVisible = effectsVisible
      self.lowestKey = firstVisibleKey
      self.highestKey = .C4
    }
  }

  public enum Action {
    case activePresetIdChanged(Preset.ID?)
    case addSoundFontButtonTapped
    case delegate(Delegate)
    case destination(PresentationAction<Destination.Action>)
    case effectsVisibilityButtonTapped
    case helpButtonTapped
    case initialize
    case presetsVisibilityButtonTapped
    case settingsButtonTapped
    case setVisibleKeyRange(lowest: Note, highest: Note)
    case shiftKeyboardUpButtonTapped
    case shiftKeyboardDownButtonTapped
    case showMoreButtonTapped
    case showTraffic(State.TrafficKind?)
    case slidingKeyboardButtonTapped
    case tagVisibilityButtonTapped

    public enum Delegate: Equatable {
      case addSoundFontButtonTapped
      case editingPresetVisibility(Bool)
      case effectsVisibilityChanged(Bool)
      case presetNameTapped
      case tagsVisibilityChanged(Bool)
      case settingsButtonTapped
      case settingsDismissed
      case visibleKeyRangeChanged(lowest: Note, highest: Note)
    }
  }

  @Shared(.firstVisibleKey) var firstVisibleKey: Note

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .activePresetIdChanged(let presetId): return activePresetIdChanged(&state, presetId: presetId)
      case .addSoundFontButtonTapped: return .send(.delegate(.addSoundFontButtonTapped))
      case .delegate: return .none
      case .destination(.dismiss): return .send(.delegate(.settingsDismissed))
      case .destination: return .none
      case .effectsVisibilityButtonTapped: return toggleEffectsVisibility(&state)
      case .helpButtonTapped: return showHelp(&state)
      case .initialize: return initialize(&state)
      case .shiftKeyboardDownButtonTapped: return shiftKeyboardDownButtonTapped(&state)
      case .shiftKeyboardUpButtonTapped: return shiftKeyboardUpButtonTapped(&state)
      case .presetsVisibilityButtonTapped: return editPresetVisibility(&state)
      case .settingsButtonTapped: return settingsButtonTapped(&state)
      case let .setVisibleKeyRange(lowest, highest): return setVisibleKeyRange(&state, lowest: lowest, highest: highest)
      case .showMoreButtonTapped: return toggleShowMoreButtons(&state)
      case .showTraffic(let kind): return showTraffic(&state, value: kind)
      case .slidingKeyboardButtonTapped: return slidingKeyboardButtonTapped(&state)
      case .tagVisibilityButtonTapped: return toggleTagsVisibility(&state)
      }
    }.ifLet(\.$destination, action: \.destination)
  }

  public init() {}

  private enum CancelId {
    case monitorActivePresetId
    case monitorMIDITraffic
  }

  @Shared(.activeState) var activeState
}

public extension ToolBarFeature {

  static func setTagsListVisible(_ state: inout State, value: Bool) {
    state.tagsListVisible = value
  }
}

private extension ToolBarFeature {

  private func activePresetIdChanged(_ state: inout State, presetId: Preset.ID?) -> Effect<Action> {
    if let presetId = presetId,
       let preset = Preset.with(key: presetId) {
      state.preset = preset
    } else {
      state.preset = nil
    }
    return .none
  }

  func editPresetVisibility(_ state: inout State) -> Effect<Action> {
    state.editingPresetVisibility.toggle()
    return .send(.delegate(.editingPresetVisibility(state.editingPresetVisibility)))
  }

  func hideMoreButtons(_ state: inout State) -> Effect<Action> {
    state.showMoreButtons = false
    return .none
  }

  func initialize(_ state: inout State) -> Effect<Action> {
    return .merge(
      monitorActivePresetId(&state),
      monitorMIDITraffic(&state)
    )
  }

  private func monitorActivePresetId(_ state: inout State) -> Effect<Action> {
    .publisher {
      $activeState.activePresetId
        .publisher
        .map { .activePresetIdChanged($0) }
    }.cancellable(id: CancelId.monitorActivePresetId, cancelInFlight: true)
  }

  func monitorMIDITraffic(_ state: inout State) -> Effect<Action> {
    guard let midiMonitor = state.midiMonitor else { return .none }
    return .run { send in
      for await traffic in midiMonitor.$traffic
        .compactMap({$0})
        .buffer(size: 1, prefetch: .byRequest, whenFull: .dropOldest)
        .values {
        await send(.showTraffic(traffic.accepted ? .accepted : .blocked))
      }
    }.cancellable(id: CancelId.monitorMIDITraffic)
  }

  func settingsButtonTapped(_ state: inout State) -> Effect<Action> {
    state.showMoreButtons = false
    return .send(.delegate(.settingsButtonTapped))
  }

  func setVisibleKeyRange(_ state: inout State, lowest: Note, highest: Note) -> Effect<Action> {
    state.lowestKey = lowest
    state.highestKey = highest
    return .none
  }

  func shiftKeyboardDownButtonTapped(_ state: inout State) -> Effect<Action> {
    let span = state.highestKey.midiNoteValue - state.lowestKey.midiNoteValue
    var newLow = Note(midiNoteValue: max(Note.midiRange.lowerBound, state.lowestKey.midiNoteValue - span))
    if newLow.accented {
      newLow = Note(midiNoteValue: newLow.midiNoteValue - 1)
    }
    let newHigh = Note(midiNoteValue: min(Note.midiRange.upperBound, newLow.midiNoteValue + span))
    state.lowestKey = newLow
    state.highestKey = newHigh
    return .send(.delegate(.visibleKeyRangeChanged(lowest: newLow, highest: newHigh)))
  }

  func shiftKeyboardUpButtonTapped(_ state: inout State) -> Effect<Action> {
    let span = state.highestKey.midiNoteValue - state.lowestKey.midiNoteValue
    let newHigh = Note(midiNoteValue: min(Note.midiRange.upperBound, state.highestKey.midiNoteValue + span))
    var newLow = Note(midiNoteValue: max(Note.midiRange.lowerBound, newHigh.midiNoteValue - span))
    if newLow.accented {
      newLow = Note(midiNoteValue: newLow.midiNoteValue - 1)
    }
    state.lowestKey = newLow
    state.highestKey = newHigh
    return .send(.delegate(.visibleKeyRangeChanged(lowest: newLow, highest: newHigh)))
  }

  func showHelp(_ state: inout State) -> Effect<Action> {
    return hideMoreButtons(&state)
  }

  func showTraffic(_ state: inout State, value: State.TrafficKind?) -> Effect<Action> {
    state.showTrafficColor = value?.color ?? .clear
    state.showTrafficPublisher.send()
    return .none
  }

  func slidingKeyboardButtonTapped(_ state: inout State) -> Effect<Action> {
    @Shared(.keyboardSlides) var keyboardSlides
    state.$keyboardSlides.withLock { $0.toggle() }
    $keyboardSlides.withLock { $0 = state.keyboardSlides }
    return .none
  }

  func toggleEffectsVisibility(_ state: inout State) -> Effect<Action> {
    state.effectsVisible.toggle()
    state.showMoreButtons = false
    return .send(.delegate(.effectsVisibilityChanged(state.effectsVisible)))
  }

  func toggleShowMoreButtons(_ state: inout State) -> Effect<Action> {
    state.showMoreButtons.toggle()
    if !state.showMoreButtons && state.editingPresetVisibility {
      state.editingPresetVisibility = false
      return .send(.delegate(.editingPresetVisibility(false)))
    }
    return .none
  }

  func toggleTagsVisibility(_ state: inout State) -> Effect<Action> {
    state.tagsListVisible.toggle()
    state.showMoreButtons = false
    return .send(.delegate(.tagsVisibilityChanged(state.tagsListVisible)))
  }
}

public struct ToolBarFeatureView: View {
  @Bindable private var store: StoreOf<ToolBarFeature>
  @Environment(\.appPanelBackground) private var appPanelBackground
  @Environment(\.auv3ControlsTheme) private var auv3ControlsTheme
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  public init(store: StoreOf<ToolBarFeature>) {
    self.store = store
  }

  public var body: some View {
    HStack(alignment: .center, spacing: 12) {
      addSoundFontButton
      toggleTagsButton
      toggleEffectsButton
      if horizontalSizeClass == .compact {
        ZStack {
          presetTitle
            .zIndex(0)
          if store.showMoreButtons {
            moreButtons
              .zIndex(1)
              .transition(.move(edge: .trailing))
          }
        }
        toggleMoreButton
          .zIndex(2)
      } else {
        presetTitle
        moreButtons
          .padding(.trailing, 8)
      }
    }
    .padding([.top, .bottom, .leading], 4)
    .background(Color.black)
    .frame(maxHeight: 40)
    .animation(.smooth, value: store.showMoreButtons)
    .task {
      await store.send(.initialize).finish()
    }
  }

  private var presetTitle: some View {
    ZStack(alignment: .leading) {
      Circle()
        .trafficBlinker(subscribedTo: store.showTrafficPublisher, color: store.showTrafficColor, duration: 0.5)
      HStack {
        Spacer()
        PresetNameView(preset: store.preset)
          .font(.status)
          .indicator(.activeNoIndicator)
          .onTapGesture {
            store.send(.delegate(.presetNameTapped))
          }
        Spacer()
      }
    }
  }

  private var addSoundFontButton: some View {
    Button {
      store.send(.addSoundFontButtonTapped)
    } label: {
      Image(systemName: "plus.circle").imageScale(.large)
    }
  }

  private var toggleTagsButton: some View {
    Button {
      store.send(.tagVisibilityButtonTapped)
    } label: {
      Image(systemName: "tag").imageScale(.large)
        .tint(store.tagsListVisible ? Color.orange : Color.accentColor)
    }
  }

  private var toggleEffectsButton: some View {
    Button {
      store.send(.effectsVisibilityButtonTapped)
    } label: {
      Image(systemName: "waveform").imageScale(.large)
        .tint(store.effectsVisible ? Color.orange : Color.accentColor)
    }
  }

  private var toggleMoreButton: some View {
    HStack(spacing: 0) {
      Button { store.send(.showMoreButtonTapped) } label: {
        Image(systemName: "chevron.left").imageScale(.large)
          .tint(store.showMoreButtons ? Color.orange : Color.accentColor)
      }
      Color.black
        .frame(width: 4)
    }
    .background(.black)
  }

  private var moreButtons: some View {
    HStack {
      Spacer()
      Button {
        store.send(.shiftKeyboardDownButtonTapped)
      } label: {
        Text("❰" + store.lowestKey.label)
      }
      .disabled(self.store.lowestKey.midiNoteValue == Note.midiRange.lowerBound)
      Button {
        store.send(.slidingKeyboardButtonTapped)
      } label: {
        Image(
          systemName: store.keyboardSlides
          ? "arrowtriangle.left.and.line.vertical.and.arrowtriangle.right.fill"
          : "arrowtriangle.left.and.line.vertical.and.arrowtriangle.right"
        )
        .tint(store.keyboardSlides ? Color.orange : Color.accentColor)
      }
      Button {
        store.send(.shiftKeyboardUpButtonTapped)
      } label: {
        Text(store.highestKey.label + "❱")
      }
      .disabled(self.store.highestKey.midiNoteValue == Note.midiRange.upperBound)
      Button {
        store.send(.settingsButtonTapped)
      } label: {
        Image(systemName: "gear").imageScale(.large)
      }
      Button {
        store.send(.presetsVisibilityButtonTapped)
      } label: {
        Image(systemName: "list.bullet").imageScale(.large)
          .tint(store.editingPresetVisibility ? Color.orange : Color.accentColor)
      }
      Button {
        store.send(.helpButtonTapped)
      } label: {
        Image(systemName: "questionmark.circle").imageScale(.large)
      }
    }
    .background(.black)
  }
}

extension ToolBarFeatureView {
  static var preview: some View {
    prepareDependencies {
      // swiftlint:disable:next force_try
      $0.defaultDatabase = try! appDatabase()
    }
    return VStack {
      ToolBarFeatureView(store: Store(initialState: .init(tagsListVisible: true, effectsVisible: false)) {
        ToolBarFeature()
      })
      KeyboardView(store: Store(initialState: .init()) { KeyboardFeature() })
    }
  }
}

#Preview {
  ToolBarFeatureView.preview
}
