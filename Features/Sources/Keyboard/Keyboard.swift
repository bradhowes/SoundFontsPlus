// Copyright © 2025 Brad Howes. All rights reserved.

import AsyncAlgorithms
import AVFAudio.AVAudioUnit
import FeatureSupport
import SwiftUI

private let log: Logger = .init(category: "Keyboard")

/**
 Representation of a virtual piano keyboard. Touching a key triggers the note assigned to the key. Handles multiple
 touches. The keyboard can be fixed or slidable. When fixed, moving a touch to a different key will release the old
 key and trigger a the note assigned to the new key. When sliding, moving a touch will scroll the keyboard in the
 direction of the touch movement.
 */
@Reducer
public struct Keyboard {

  @ObservableState
  public struct State: Equatable {

    /**
     Wrapper around a `SpatialEventId` prototype value that allows us to use them as keys in a dictionary.
     */
    public struct EventId {
      public typealias Equals = (any SpatialEventId, any SpatialEventId) -> Bool

      public let value: any SpatialEventId
      public let equals: Equals

      /**
       Initialize a new instance with a `SpatialEventId` value and a closure that can compare it to another
       `SpatialEventId` to determine if the two are the same value.
       */
      public init(_ value: any SpatialEventId, equals: @escaping Equals) {
        self.value = value
        self.equals = equals
      }
    }

    // Mapping from unique event ID to a Note value.
    public var eventNoteMap: [EventId: Note] = [:]

    // Collection of activation counters for MIDI notes. A counter can be > 1 but it will only trigger a note ON in the
    // synth when it becomes 1, and it will only trigger a note OFF when it becomes 0.
    public var noteCounters: [Int] = .init(repeating: 0, count: Note.midiRange.count)

    public var muted: Bool
    public let settingsDemo: Bool
    public var scrollTo: Note?
    public var midiInstrument: AVAudioUnitMIDIInstrument?

    @Shared(.keyWidth) public var keyWidth
    @Shared(.keyLabels) public var keyLabels

    public init(
      muted: Bool = false,
      settingsDemo: Bool = false,
      activeNotes: [(EventId, Note)] = []
    ) {
      @Shared(.firstVisibleKey) var firstVisibleKey
      self.muted = muted
      self.scrollTo = firstVisibleKey
      self.settingsDemo = settingsDemo
      for (event, note) in activeNotes {
        self.eventNoteMap[event] = note
        self.noteCounters[note.midiNoteValue] = 1
      }
    }
  }

  public enum OutputVolumeState {
    case muted
    case unmuted
  }

  public enum Action {
    case activePresetIdChanged(Preset.ID?)
    case allOff
    case deinitialize
    case delegate(Delegate)
    case midiInstrumentCreated(AVAudioUnit)
    case outputVolumeStateChanged(OutputVolumeState)
    case scrollTo(Note?)
    case touchBegan(State.EventId, Note)
    case touchEnded(State.EventId)
    case updateVisibleKeys(lowest: Note, highest: Note)
    case visualizeMIDINote(MIDINote)

    @CasePathable
    public enum Delegate {
      case noteOn(Note)
      case visibleKeyRangeChanged(lowest: Note, highest: Note)
    }
  }

  public init() {}

  @Shared(.showMIDINotesOnKeyboard) private var showMIDINotesOnKeyboard

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in

      log.action("Keyboard", action)

      switch action {

      case let .activePresetIdChanged(presetId):
        return Self.activePresetIdChanged(&state, presetId: presetId)

      case .allOff:
        state.eventNoteMap.removeAll()
        state.noteCounters = .init(repeating: 0, count: state.noteCounters.count)
        return .none

      case .deinitialize:
        return .merge(CancelId.allCases.map { .cancel(id: $0) })

      case .delegate:
        return .none

      case .midiInstrumentCreated(let audioUnit):
        state.midiInstrument = audioUnit.midiInstrument
        return monitorMIDINotes(&state)

      case .outputVolumeStateChanged(let value):
        state.muted = value == .muted
        return .none

      case let .scrollTo(key):
        state.scrollTo = key
        return .none

      case let .touchBegan(event, note):
        return touchBegan(&state, event: event, note: note)

      case let .touchEnded(event):
        return touchEnded(&state, event: event)

      case let .updateVisibleKeys(lowest, highest):
        return updateVisibleKeys(&state, lowest: lowest, highest: highest)

      case let .visualizeMIDINote(note):
        return visualizeMIDINote(&state, note: note)
      }
    }
  }

  private enum CancelId: String, CaseIterable {
    case keyboardMonitorMIDINotes
    case keyboardScrollTo
  }
}

extension Keyboard.State.EventId: Hashable {
  public static func == (a: Self, b: Self) -> Bool { a.equals(a.value, b.value) }
  public func hash(into hasher: inout Hasher) { value.hash(into: &hasher) }
}

extension Keyboard.State.EventId {

  /**
   Factory method to wrap a `SpatialEventGesture.Value.Element.ID` value in a `Keyboard.State.EventId`
   */
  static func wrap(_ id: SpatialEventGesture.Value.Element.ID) -> Self {
    .init(
      id,
      equals: { ($0 as? SpatialEventGesture.Value.Element.ID) == ($1 as? SpatialEventGesture.Value.Element.ID) }
    )
  }
}

extension Keyboard {

  public static func activePresetIdChanged(_ state: inout State, presetId: Preset.ID?) -> Effect<Action> {
    guard let presetId = presetId else { return .none }
    guard let audioConfig = AudioConfig.with(presetId: presetId) else { return .none }
    guard audioConfig.keyboardLowestNoteEnabled else { return .none }
    state.noteCounters = .init(repeating: 0, count: state.noteCounters.count)
    log.info("activePresetidChanged - scrollTo \(audioConfig.keyboardLowestNote)")
    return .run { send in
      await send(.scrollTo(audioConfig.keyboardLowestNote))
    }.cancellable(id: CancelId.keyboardScrollTo)
  }

  private func monitorMIDINotes(_ state: inout State) -> Effect<Action> {
    @Shared(.midiMonitor) var midiMonitor
    guard let midiMonitor else { return .none }
    return .run { send in
      for await note in midiMonitor.$notes.values.compacted() {
        await send(.visualizeMIDINote(note))
      }
    }.cancellable(id: CancelId.keyboardMonitorMIDINotes)
  }

  private func reduceNoteCount(_ state: inout State, note: Note) -> Bool {
    let count = state.noteCounters[note.midiNoteValue]
    if count >= 1 {
      state.noteCounters[note.midiNoteValue] = count - 1
    }
    return count == 1
  }

  private func touchBegan(_ state: inout State, event: State.EventId, note: Note) -> Effect<Action> {
    @Shared(.keyboardSlides) var keyboardSlides
    if let previous = state.eventNoteMap[event] {

      // Same note being activated or keyboard slides then nothing to change in state
      if previous == note || keyboardSlides {
        return .none
      }

      // If key is no longer held down, stop the note
      if reduceNoteCount(&state, note: previous) {
        state.midiInstrument?.stopNote(UInt8(previous.midiNoteValue), onChannel: 0)
      }
    }

    state.eventNoteMap[event] = note
    state.noteCounters[note.midiNoteValue] += 1

    // If first time touching the key, start playing the note for it
    if state.noteCounters[note.midiNoteValue] == 1 {
      if !state.muted {
        state.midiInstrument?.startNote(UInt8(note.midiNoteValue), withVelocity: 127, onChannel: 0)
      }
      return .send(.delegate(.noteOn(note)))
    }

    return .none
  }

  private func touchEnded(_ state: inout State, event: State.EventId) -> Effect<Action> {
    if let note = state.eventNoteMap.removeValue(forKey: event),
       reduceNoteCount(&state, note: note) {
      state.midiInstrument?.stopNote(UInt8(note.midiNoteValue), onChannel: 0)
    }
    return .none
  }

  private func updateVisibleKeys(_ state: inout State, lowest: Note, highest: Note) -> Effect<Action> {
    return .run { send in
      await send(.delegate(.visibleKeyRangeChanged(lowest: lowest, highest: highest)))
    }
  }

  private func visualizeMIDINote(_ state: inout State, note: MIDINote) -> Effect<Action> {
    guard showMIDINotesOnKeyboard else { return .none }
    switch note {
    case let .on(note):
      state.noteCounters[note.midiNoteValue] += 1
    case let .off(note):
      state.noteCounters[note.midiNoteValue] = max(state.noteCounters[note.midiNoteValue] - 1, 0)
    }
    return .none
  }
}

// MARK: - View

public struct KeyboardView: View {
  typealias Event = SpatialEventGesture.Value.Element
  private var store: StoreOf<Keyboard>
  @State private var frames: [CGRect] = Array(repeating: .zero, count: Note.midiRange.count)
  @Shared(.keyboardSlides) private var keyboardSlides

  @Environment(\.maxKeyboardPanelHeight) private var maxKeyboardPanelHeight
  @Environment(\.verticalSizeClass) private var verticalSizeClass

  private var activeColor: Color { store.muted ? .red : .green }
  private let whiteNotes: [Note] = .init(WhiteKeySequenceGenerator().makeIterator())
  private let blackNotes: [Note] = .init(BlackKeySequenceGenerator().makeIterator())

  private var keyboardHeightScaling: Double { verticalSizeClass == .compact ? 0.5 : 1.0 }
  private var keyboardHeight: Double { maxKeyboardPanelHeight * keyboardHeightScaling }
  private let whiteKeySpacing: Double = 2.0
  private let whiteKeyInset: Double
  private let coordinateSpace = "keyboard"

  @State private var visibleRect: CGRect = .zero

  public init(store: StoreOf<Keyboard>) {
    self.store = store
    self.whiteKeyInset = whiteKeySpacing * -2.0
  }

  public var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal) {
        keys
      }
      .coordinateSpace(name: coordinateSpace)
      .simultaneousGesture(spatialEventGesture)
      .scrollDisabled(!keyboardSlides)
      .scrollIndicators(.hidden)
      .onChange(of: store.scrollTo) { old, new in
        if let key = new, old != key {
          if store.settingsDemo {
            proxy.scrollTo(Note.lowest, anchor: .leading)
            store.send(.scrollTo(nil))
          } else {
            withAnimation {
              proxy.scrollTo(key, anchor: .leading)
            }
          }
        }
      }
      .background(Color.panelBackgroundColor)
      .onScrollGeometryChange(for: CGRect.self) { geometry in
        geometry.visibleRect
      } action: { _, newValue in
        if store.scrollTo != nil {
          proxy.scrollTo(store.scrollTo, anchor: .leading)
          store.send(.scrollTo(nil))
        } else {
          updateVisibleKeys(visibleRect: newValue)
        }
      }
    }
    .clipShape(
      Rectangle()
    )
  }

  private func updateVisibleKeys(visibleRect: CGRect) {
    let low = Int(visibleRect.origin.x / (store.keyWidth + whiteKeySpacing))
    let high = Int((visibleRect.origin.x + visibleRect.size.width) / (store.keyWidth + whiteKeySpacing))
    if low >= 0 && high <= 127 {
      store.send(
        .updateVisibleKeys(
          lowest: whiteNotes[max(0, low)],
          highest: whiteNotes[min(high, whiteNotes.count - 1)]
        )
      )
    }
  }

  public var keys: some View {
    whiteKeys
      .overlay(alignment: .topLeading) {
        blackKeys
      }
  }

  private var spatialEventGesture: some Gesture {
    SpatialEventGesture(coordinateSpace: .named(coordinateSpace))
      .onChanged { events in
        for event in events {
          if event.phase == .active {
            touchDown(to: event)
          } else {
            touchUp(for: event)
          }
        }
      }
      .onEnded { events in
        for event in events {
          touchUp(for: event)
        }
      }
  }

  private var whiteKeys: some View {
    HStack(alignment: .top, spacing: whiteKeySpacing) {
      ForEach(0..<75) { noteIndex in
        whiteKey(note: whiteNotes[noteIndex])
      }
    }
  }

  private func whiteKey(note: Note) -> some View {
    labeledKey(note: note)
      .onGeometryChange(for: CGRect.self) {
        $0.frame(in: .named(coordinateSpace))
      } action: {
        if note.isValidMidiNote {
          frames[note.midiNoteValue] = $0.insetBy(dx: whiteKeyInset, dy: 0)
        }
      }
  }

  private var blackKeys: some View {
    let blackKeyWidth: Double = store.keyWidth * 0.75
    let offset = blackKeyWidth / 2.0
    let spacing = store.keyWidth + whiteKeySpacing - blackKeyWidth
    return HStack(alignment: .top, spacing: spacing) {
      Color(.clear)
        .frame(width: offset)
      ForEach(0..<74) { noteIndex in
        blackKey(note: blackNotes[noteIndex])
      }
    }
  }

  private func blackKey(note: Note) -> some View {
    key(note: note)
      .opacity(note.isValidMidiNote ? 1.0 : 0.0)
      .onGeometryChange(for: CGRect.self) {
        $0.frame(in: .named(coordinateSpace))
      } action: {
        if note.isValidMidiNote {
          frames[note.midiNoteValue] = $0
        }
      }
  }

  private func key(note: Note) -> some View {
    let color: Color = note.accented ? .black : .white
    let width: Double = note.accented ? store.keyWidth * 0.75 : store.keyWidth
    let height: Double = maxKeyboardPanelHeight * (note.accented ? 0.6 : 1.0) * keyboardHeightScaling
    let cornerRadius: Double = 8

    return RoundedRectangle(cornerRadius: cornerRadius)
      .fill(color)
      .fill((note.isValidMidiNote && store.noteCounters[note.midiNoteValue] > 0) ? activeColor.opacity(0.3) : .clear)
      .frame(width: width, height: height)
      .offset(y: -cornerRadius / 2)
      .id(note)
  }

  private func labeledKey(note: Note) -> some View {
    key(note: note)
      .overlay(alignment: .bottom) {
        if (store.keyLabels.all && !note.accented) || (store.keyLabels.cOnly && note.noteIndex == 0) {
          Text(note.description)
            .foregroundStyle(.gray)
            .offset(y: -12)
        }
      }
  }

  private func touchDown(to event: Event) {
    print("touchDown:", event.location)

    // NOTE: seems that on iPad OS 26.1 we can get phantom events where X is near 0.0 and Y is just below the bottom of
    // the screen. Do not see this on iPhone devices.
    guard isValidTouchLocation(event.location) else {
      print("*** ignored")
      return
    }

    let pos = frames.orderedInsertionIndex(for: event.location)
    guard pos < frames.endIndex else { return }
    let note = Note(midiNoteValue: frames.distance(from: frames.startIndex, to: pos))
    store.send(.touchBegan(.wrap(event.id), note))
  }

  private func touchUp(for event: Event) {
    print("touchUp:", event.location)
    guard isValidTouchLocation(event.location) else {
      print("*** ignored")
      return
    }
    store.send(.touchEnded(.wrap(event.id)))
  }

  private func isValidTouchLocation(_ location: CGPoint) -> Bool {
    location.x > 1.0e-8 && location.y < keyboardHeight
  }
}

#if DEBUG

struct KeyboardPreview: View {
  var store: StoreOf<Keyboard> = Store(initialState: .init()) { Keyboard() }

  @Shared(.keyWidth) var keyWidth
  @Shared(.keyboardSlides) var keyboardSlides
  @Shared(.keyLabels) var keyLabels

  var body: some View {
    VStack {
      KeyboardView(store: store)
        .animation(.smooth, value: keyWidth.rounded())
      Slider(
        value: Binding<Double>(
          get: { keyWidth },
          set: { newValue in $keyWidth.withLock { $0 = newValue } }
        ),
        in: 32...96
      )
      Text("Width: \(Int(keyWidth.rounded()))")
      Toggle(
        isOn: Binding<Bool>(
          get: { keyboardSlides },
          set: { newValue in $keyboardSlides.withLock { $0 = newValue } }
        )
      ) { Text("Slides") }
      HStack {
        Text("Key Labels")
        Spacer()
        Picker(
          selection: Binding<KeyLabels>(
            get: { keyLabels },
            set: { newValue in $keyLabels.withLock { $0 = newValue } }
          )
        ) {
          ForEach(KeyLabels.allCases) { kind in
            Text(kind.rawValue)
          }
        } label: {
          Text("Labels")
        }
      }
    }
  }
}

#Preview {
  // swiftlint:disable:next redundant_discardable_let
  let _ = prepareDependencies {
    $0.defaultDatabase = previewDatabase()
    @Shared(.firstVisibleKey) var firstVisibleKey
    $firstVisibleKey.withLock { $0 = .C4 }
    @Shared(.keyboardSlides) var keyboardSlides
    $keyboardSlides.withLock { $0 = true }
  }
  KeyboardPreview()
}

#endif // DEBUG
