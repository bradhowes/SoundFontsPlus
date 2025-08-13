// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import ComposableArchitecture
import Dependencies
import SF2LibAU
import SwiftUI

@Reducer
public struct KeyboardFeature {
  public typealias Event = SpatialEventGesture.Value.Element

  @ObservableState
  public struct State: Equatable {
    var active: [Bool] = .init(repeating: false, count: Note.midiRange.count)

    @Shared(.keyWidth) var keyWidth
    @Shared(.keyboardSlides) var keyboardSlides
    @Shared(.keyLabels) var keyLabels

    var synth: AVAudioUnitMIDIInstrument?
    var scrollTo: Note?
    let settingsDemo: Bool

    public init(settingsDemo: Bool = false) {
      @Shared(.firstVisibleKey) var firstVisibleKey
      self.scrollTo = firstVisibleKey
      self.settingsDemo = settingsDemo
    }
  }

  public enum Action: Equatable {
    case activePresetIdChanged(Preset.ID?)
    case allOff
    case keyAssigned(previous: Note?, note: Note)
    case clearScrollTo
    case delegate(Delegate)
    case initialize
    case keyReleased(note: Note)
    case scrollTo(Note)
    case updateVisibleKeys(lowest: Note, highest: Note)

    public enum Delegate: Equatable {
      case visibleKeyRangeChanged(lowest: Note, highest: Note)
    }
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case let .activePresetIdChanged(presetId):
        return activePresetIdChanged(&state, presetId: presetId)
      case .allOff:
        state.active = .init(repeating: false, count: state.active.count)
      case let .keyAssigned(previous, key):
        return keyAssigned(&state, previous: previous, key: key)
      case let .keyReleased(note):
        return noteOff(&state, key: note)
      case .clearScrollTo:
        state.scrollTo = nil
      case .initialize:
        return initialize(&state)
      case let .scrollTo(key):
        state.scrollTo = key
      case let .updateVisibleKeys(lowest, highest):
        return updateVisibleKeys(&state, lowest: lowest, highest: highest)
      default:
        return .none
      }
      return .none
    }
  }

  private enum CancelId {
    case activePresetId
    case scrollTo
  }

  @Shared(.activeState) var activeState
}

extension KeyboardFeature {

  private func activePresetIdChanged(_ state: inout State, presetId: Preset.ID?) -> Effect<Action> {
    guard let presetId = presetId else { return .none }
    guard let audioConfig = AudioConfig.with(key: presetId) else { return .none }
    guard audioConfig.keyboardLowestNoteEnabled else { return .none }
    state.active = .init(repeating: false, count: state.active.count)
    return .run { send in
      await send(.scrollTo(audioConfig.keyboardLowestNote))
    }.cancellable(id: CancelId.scrollTo)
  }

  private func keyAssigned(_ state: inout State, previous: Note?, key: Note) -> Effect<Action> {
    guard previous != key else { return .none }
    if let previous {
      _ = noteOff(&state, key: previous)
    }
    return noteOn(&state, key: key)
  }

  private func initialize(_ state: inout State) -> Effect<Action> {
    .publisher {
      $activeState.activePresetId
        .publisher
        .map { .activePresetIdChanged($0) }
    }.cancellable(id: CancelId.activePresetId, cancelInFlight: true)
  }

  private func noteOff(_ state: inout State, key: Note) -> Effect<Action> {
    state.active[key.midiNoteValue] = false
    state.synth?.stopNote(UInt8(key.midiNoteValue), onChannel: 0)
    return .none
  }

  private func noteOn(_ state: inout State, key: Note) -> Effect<Action> {
    state.active[key.midiNoteValue] = true
    state.synth?.startNote(UInt8(key.midiNoteValue), withVelocity: 127, onChannel: 0)
    return .none
  }

  private func updateVisibleKeys(_ state: inout State, lowest: Note, highest: Note) -> Effect<Action> {
    return .run { send in
      await send(.delegate(.visibleKeyRangeChanged(lowest: lowest, highest: highest)))
    }
  }
}

public struct KeyboardView: View {
  typealias Event = SpatialEventGesture.Value.Element
  @State private var store: StoreOf<KeyboardFeature>
  @State private var eventNoteMap = EventNoteMap()
  @State private var frames: [CGRect] = Array(repeating: .zero, count: Note.midiRange.count)

  @Environment(\.verticalSizeClass) private var verticalSizeClass
  @Environment(\.keyboardHeight) private var keyboardHeight

  private let whiteNotes: [Note] = .init(WhiteKeySequenceGenerator().makeIterator())
  private let blackNotes: [Note] = .init(BlackKeySequenceGenerator().makeIterator())

  private var keyboardHeightScaling: Double { verticalSizeClass == .compact ? 0.5 : 1.0 }
  private let whiteKeySpacing: Double = 2.0

  public init(store: StoreOf<KeyboardFeature>) {
    self.store = store
  }

  public var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal) {
        if store.keyboardSlides {
          scrollingKeys
        } else {
          fixedKeys
        }
      }
      .onChange(of: store.scrollTo) { old, new in
        if let key = new, old != key {
          if store.settingsDemo {
            proxy.scrollTo(Note.lowest, anchor: .leading)
            store.send(.clearScrollTo)
          } else {
            withAnimation {
              proxy.scrollTo(key, anchor: .leading)
            }
          }
        }
      }
      .background(.panelBackground)
      .onScrollGeometryChange(for: CGRect.self) { geometry in
        geometry.visibleRect
      } action: { _, newValue in
        if store.scrollTo != nil {
          proxy.scrollTo(store.scrollTo, anchor: .leading)
          store.send(.clearScrollTo)
        } else {
          updateVisibleKeys(visibleRect: newValue)
        }
      }
      .onAppear {
        store.send(.initialize)
      }
    }
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

  public var fixedKeys: some View {
    whiteKeys
      .overlay(alignment: .topLeading) {
        blackKeys
      }
      .highPriorityGesture(spatialEventGesture)
  }

  public var scrollingKeys: some View {
    whiteKeys
      .overlay(alignment: .topLeading) {
        blackKeys
      }
      .simultaneousGesture(spatialEventGesture)
  }

  private var spatialEventGesture: some Gesture {
    SpatialEventGesture(coordinateSpace: .global)
      .onChanged { events in
        for event in events {
          if event.phase == .active {
            assignNote(to: event)
          } else {
            releaseNote(for: event)
          }
        }
      }
      .onEnded { events in
        for event in events {
          releaseNote(for: event)
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
        $0.frame(in: .global)
      } action: {
        if note.isValidMidiNote {
          frames[note.midiNoteValue] = $0
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
        $0.frame(in: .global)
      } action: {
        if note.isValidMidiNote {
          frames[note.midiNoteValue] = $0
        }
      }
  }

  private func key(note: Note) -> some View {
    let color: Color = note.accented ? .black : .white
    let width: Double = note.accented ? store.keyWidth * 0.75 : store.keyWidth
    let height: Double = (note.accented ? keyboardHeight * 0.6 : keyboardHeight) * keyboardHeightScaling
    let cornerRadius: Double = 8

    return RoundedRectangle(cornerRadius: cornerRadius)
      .fill(color)
      .fill(eventNoteMap.isOn(note) ? Color.green.opacity(0.3) : .clear)
      .frame(width: width, height: height + cornerRadius)
      .offset(y: -cornerRadius)
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

  private func assignNote(to event: Event) {
    let pos = frames.orderedInsertionIndex(for: event.location)
    guard pos < frames.endIndex else { return }
    let note = Note(midiNoteValue: frames.distance(from: frames.startIndex, to: pos))
    let update = eventNoteMap.assign(event: event, note: note, fixedKeys: !store.keyboardSlides)
    if update.previous != nil || update.firstTime {
      store.send(.keyAssigned(previous: update.previous, note: note))
    }
  }

  private func releaseNote(for event: Event) {
    if let note = eventNoteMap.release(event: event) {
      store.send(.keyReleased(note: note))
    }
  }
}

extension RandomAccessCollection where Element == CGRect, Index == Int {

  /**
   Obtain the index of the key in the collection that corresponds to the given position. Performs a binary search to
   quickly locate the best candidate.

   - parameter point: the location to consider
   - returns: index where to insert
   */
  func orderedInsertionIndex(for point: CGPoint) -> Index {
    var low = startIndex
    var high = endIndex

    while low != high {
      let mid = index(low, offsetBy: distance(from: low, to: high) / 2)
      let frame = self[mid]
      if frame.contains(point) {
        low = mid
        break
      }
      if frame.midX < point.x {
        low = index(after: mid)
      } else {
        high = mid
      }
    }

    // Don't continue if outside of collection
    guard low < endIndex else { return endIndex }

    // Don't continue if referencing an accented note -- there is no ambiguity and we have what we want
    let key = Note(midiNoteValue: distance(from: startIndex, to: low))
    guard !key.accented else { return low }

    // Point is in the region of a white key. Check if previous or next key is accented and has the point to handle the
    // overlap of the black keys on the white ones.
    let next = index(after: low)
    if next != endIndex && Note(midiNoteValue: next).accented && self[next].contains(point) {
      return next
    }

    let prev = index(before: low)
    if prev >= startIndex && Note(midiNoteValue: prev).accented && self[prev].contains(point) {
      return prev
    }

    return low
  }
}

struct KeyboardPreview: View {
  @State var store: StoreOf<KeyboardFeature> = Store(initialState: .init()) { KeyboardFeature() }

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

extension FloatingPoint {
  var whole: Self { modf(self).0 }
  var fraction: Self { modf(self).1 }
}

#Preview {
  prepareDependencies {
    // swiftlint:disable:next force_try
    $0.defaultDatabase = try! appDatabase()
    @Shared(.firstVisibleKey) var firstVisibleKey
    $firstVisibleKey.withLock { $0 = .C4 }
    @Shared(.keyboardSlides) var keyboardSlides
    $keyboardSlides.withLock { $0 = true }
  }

  return KeyboardPreview()
}
