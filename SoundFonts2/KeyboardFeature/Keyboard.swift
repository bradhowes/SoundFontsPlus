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
    @Shared(.lowestKey) var lowestKey
    @Shared(.highestKey) var highestKey
    var scrollTo: Note?
    let settingsDemo: Bool

    public init(settingsDemo: Bool = false) {
      self.settingsDemo = settingsDemo
    }
  }

  public enum Action: Equatable {
    case allOff
    case assigned(previous: Note?, note: Note)
    case noteOff(Note)
    case noteOn(Note)
    case released(note: Note)
    case updatedVisibleKeys(lowest: Note, highest: Note)
    case postScrollTo
    case clearScrollTo

    public enum Delegate: Equatable {
      case visibleKeyRangeChanged(lowest: Note, highest: Note)
    }
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .allOff:
        state.active = .init(repeating: false, count: state.active.count)
        return .none
      case let .assigned(previous, note):
        if let previous {
          state.active[previous.midiNoteValue] = false
        }
        state.active[note.midiNoteValue] = true
        return .none
      case let .noteOff(note):
        state.active[note.midiNoteValue] = false
        return .none
      case let .noteOn(note):
        state.active[note.midiNoteValue] = true
        return .none
      case let .released(note):
        state.active[note.midiNoteValue] = false
        return .none
      case let .updatedVisibleKeys(lowest, highest):
        state.$lowestKey.withLock { $0 = lowest }
        state.$highestKey.withLock { $0 = highest }
        return .none
      case .postScrollTo:
        state.scrollTo = state.settingsDemo ? Note.lowest : state.lowestKey
        return .none
      case .clearScrollTo:
        state.scrollTo = nil
        return .none
      }
    }
  }
}

extension KeyboardFeature {

  private func assign(_ state: inout State, event: Event, note: Note) -> Effect<Action> {
    // _ = state.eventNoteMap.assign(event: event, note: note)
    return .none
  }

  private func release(_ state: inout State, event: Event) -> Effect<Action> {
    // _ = state.eventNoteMap.release(event: event)
    return .none
  }
}

public struct KeyboardView: View {
  typealias Event = SpatialEventGesture.Value.Element

  @Shared(.keyWidth) var keyWidth
  @Shared(.keyboardSlides) var keyboardSlides
  @Shared(.keyLabels) var keyLabels

  @State private var store: StoreOf<KeyboardFeature>

  public let whiteNotes: [Note] = .init(WhiteKeySequenceGenerator().makeIterator())
  public let blackNotes: [Note] = .init(BlackKeySequenceGenerator().makeIterator())

  @State private var eventNoteMap = EventNoteMap()
  @State private var frames: [CGRect] = Array(repeating: .zero, count: Note.midiRange.count)

  @Environment(\.verticalSizeClass) private var verticalSizeClass
  @Environment(\.keyboardHeight) private var keyboardHeight

  private var keyboardHeightScaling: Double { verticalSizeClass == .compact ? 0.5 : 1.0 }
  private let whiteKeySpacing: Double = 2.0

  public init(store: StoreOf<KeyboardFeature>) {
    self.store = store
  }

  public var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal) {
        if keyboardSlides {
          scrollingKeys
        } else {
          fixedKeys
        }
      }
      .onAppear {
        proxy.scrollTo(store.settingsDemo ? Note.lowest : store.lowestKey, anchor: .leading)
      }
      .onChange(of: store.lowestKey) {
        withAnimation {
          proxy.scrollTo(store.settingsDemo ? Note.lowest : store.lowestKey, anchor: .leading)
        }
      }
      .background(.black)
      .onScrollPhaseChange { oldPhase, newPhase, context in
        if oldPhase != newPhase && newPhase == .idle {
          store.send(
            .updatedVisibleKeys(
              lowest: lowestNote(context.geometry),
              highest: highestNote(context.geometry)
            )
          )
        }
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
          print("key: \(note)")
          frames[note.midiNoteValue] = $0
        }
      }
  }

  private var blackKeys: some View {
    let blackKeyWidth: Double = keyWidth * 0.75
    let offset = blackKeyWidth / 2.0
    let spacing = keyWidth + whiteKeySpacing - blackKeyWidth
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
          print("key: \(note)")
          frames[note.midiNoteValue] = $0
        }
      }
  }

  private func key(note: Note) -> some View {
    let color: Color = note.accented ? .black : .white
    let width: Double = note.accented ? keyWidth * 0.75 : keyWidth
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
        if (keyLabels.all && !note.accented) || (keyLabels.cOnly && note.noteIndex == 0) {
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
    let update = eventNoteMap.assign(event: event, note: note, fixedKeys: !keyboardSlides)
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
  @Shared(.keyWidth) var keyWidth
  @Shared(.keyboardSlides) var keyboardSlides
  @Shared(.keyLabels) var keyLabels
  @Shared(.lowestKey) var lowestKey
  @Shared(.highestKey) var highestKey

  var body: some View {
    VStack {
      KeyboardView(store: Store(initialState: .init()) { KeyboardFeature() })
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
        Text(lowestKey.label)
        Text(highestKey.label)
      }
    }
  }
}

extension FloatingPoint {
  var whole: Self { modf(self).0 }
  var fraction: Self { modf(self).1 }
}

#Preview {
  KeyboardPreview()
}
