// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import Dependencies
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

    var lowestKey: Note = .C4
    var highestKey: Note = .C4
    var scrollTo: Note?
    let settingsDemo: Bool

    public init(settingsDemo: Bool = false) {
      self.settingsDemo = settingsDemo
      print("keyboard: \(lowestKey) - \(highestKey) \(settingsDemo)")
    }
  }

  public enum Action: Equatable {
    case activePresetIdChanged(Preset.ID?)
    case allOff
    case assigned(previous: Note?, note: Note)
    case clearScrollTo
    case delegate(Delegate)
    case monitorStateChanges
    case noteOff(Note)
    case noteOn(Note)
    case released(note: Note)
    case scrollTo(Note)
    case updatedVisibleKeys(lowest: Note, highest: Note)

    public enum Delegate: Equatable {
      case visibleKeyRangeChanged(lowest: Note, highest: Note)
    }
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case let .activePresetIdChanged(presetId): return activePresetIdChanged(&state, presetId: presetId)
      case .allOff: return allOff(&state)
      case let .assigned(previous, key): return assigned(&state, previous: previous, key: key)
      case .clearScrollTo: return clearScrollTo(&state)
      case .delegate: return .none
      case .monitorStateChanges: return monitorStateChanges(&state)
      case let .noteOff(note): return noteOff(&state, key: note)
      case let .noteOn(note): return noteOn(&state, key: note)
      case let .released(note): return noteOff(&state, key: note)
      case let .scrollTo(key): return scrollTo(&state, key: key)
      case let .updatedVisibleKeys(lowest, highest): return updateVisibleKeys(&state, lowest: lowest, highest: highest)
      }
    }
  }

  let publisherCancelId = "PresetsList.publisherCancelId"
}

extension KeyboardFeature {

  private func activePresetIdChanged(_ state: inout State, presetId: Preset.ID?) -> Effect<Action> {
    guard let presetId = presetId else { return .none }
    guard let preset = Preset.with(key: presetId) else { return .none }
    guard let audioConfig = preset.audioConfig else { return .none }
    guard audioConfig.keyboardLowestNoteEnabled else { return .none }
    state.lowestKey = audioConfig.keyboardLowestNote
    return .none
  }

  private func allOff(_ state: inout State) -> Effect<Action> {
    state.active = .init(repeating: false, count: state.active.count)
    return .none
  }

  private func assigned(_ state: inout State, previous: Note?, key: Note) -> Effect<Action> {
    if let previous {
      state.active[previous.midiNoteValue] = false
    }
    state.active[key.midiNoteValue] = true
    return .none
  }

  private func clearScrollTo(_ state: inout State) -> Effect<Action> {
    state.scrollTo = nil
    return .none
  }

  private func monitorStateChanges(_ state: inout State) -> Effect<Action> {
    state.scrollTo = state.lowestKey
    return .merge(
      .publisher {
        @Shared(.activeState) var activeState
        return $activeState.activePresetId.publisher.map { Action.activePresetIdChanged($0) }
      }.cancellable(id: publisherCancelId, cancelInFlight: true),
      .publisher {
        @Shared(.firstVisibleKey) var firstVisibleKey
        return $firstVisibleKey.publisher.map { Action.scrollTo($0) }
      }
    )
  }

  private func noteOff(_ state: inout State, key: Note) -> Effect<Action> {
    state.active[key.midiNoteValue] = false
    return .none
  }

  private func noteOn(_ state: inout State, key: Note) -> Effect<Action> {
    state.active[key.midiNoteValue] = true
    return .none
  }

  private func scrollTo(_ state: inout State, key: Note) -> Effect<Action> {
    state.scrollTo = key
    return .none
  }

  private func updateVisibleKeys(_ state: inout State, lowest: Note, highest: Note) -> Effect<Action> {
    state.lowestKey = lowest
    state.highestKey = highest
    return .send(.delegate(.visibleKeyRangeChanged(lowest: lowest, highest: highest)))
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
      .onChange(of: store.lowestKey) {
        store.send(.scrollTo(store.lowestKey))
      }
      .onChange(of: store.scrollTo) {
        withAnimation {
          proxy.scrollTo(store.settingsDemo ? Note.lowest : (store.scrollTo ?? store.lowestKey), anchor: .leading)
        }
      }
      .background(.black)
      .onScrollPhaseChange { oldPhase, newPhase, context in
        if store.scrollTo != nil && newPhase == .idle {
          store.send(
            .updatedVisibleKeys(
              lowest: lowestNote(context.geometry),
              highest: highestNote(context.geometry)
            )
          )
        }
      }
      .onAppear {
        store.send(.monitorStateChanges)
      }
    }
  }

  private func lowestNote(_ geometry: ScrollGeometry) -> Note {
    // This is not exactly right since the last key does not have `whiteKeySpacing` but it is good enough for the
    // lowest note calculation.
    let numerator = geometry.contentOffset.x + whiteKeySpacing - 1
    let denominator = geometry.contentSize.width
    let position = numerator / denominator * Double(whiteNotes.count)
    let index = max(0, Int(position.fraction > 0.8 ? position + 1 : position))
    return whiteNotes[index]
  }

  private func highestNote(_ geometry: ScrollGeometry) -> Note {
    // Use the right (trailing) side of the scroll view to determine what key is visible.
    let numerator = geometry.contentOffset.x + geometry.bounds.width - 1
    let denominator = geometry.contentSize.width
    let position = numerator / denominator * Double(whiteNotes.count)
    let index = min(whiteNotes.count - 1, Int(position.fraction < 0.2 ? position - 1 : position))
    return whiteNotes[index]
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
            forgetNote(for: event)
          }
        }
      }
      .onEnded { events in
        for event in events {
          forgetNote(for: event)
        }
      }
  }

  private var whiteKeys: some View {
    HStack(alignment: .top, spacing: whiteKeySpacing){
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
      store.send(.assigned(previous: update.previous, note: note))
    }
  }

  private func forgetNote(for event: Event) {
    if let note = eventNoteMap.release(event: event) {
      store.send(.released(note: note))
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
      HStack {
        Text(store.lowestKey.label)
        Text(store.highestKey.label)
      }
    }
  }
}

extension FloatingPoint {
  var whole: Self { modf(self).0 }
  var fraction: Self { modf(self).1 }
}

#Preview {
  let _ = prepareDependencies {
    $0.defaultDatabase = try! appDatabase()
    @Shared(.firstVisibleKey) var firstVisibleKey
    $firstVisibleKey.withLock { $0 = .C4 }
    @Shared(.keyboardSlides) var keyboardSlides
    $keyboardSlides.withLock { $0 = true }
  }

  KeyboardPreview()
}
