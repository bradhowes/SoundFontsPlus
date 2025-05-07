// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import Dependencies
import Extensions
import SwiftUI
import Utils

@Reducer
public struct KeyboardFeature {
  public typealias Event = SpatialEventGesture.Value.Element

  @ObservableState
  public struct State: Equatable {
    public var active: [Bool] = .init(repeating: false, count: 128)

    public init() {}
  }

  public enum Action: Equatable {
    case allOff
    case assigned(previous: Note?, note: Note)
    case noteOff(Note)
    case noteOn(Note)
    case released(note: Note)
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

  @State private var store: StoreOf<KeyboardFeature>

  public let whiteNotes: [Note] = .init(WhiteKeySequenceGenerator().makeIterator())
  public let blackNotes: [Note] = .init(BlackKeySequenceGenerator().makeIterator())

  @State private var eventNoteMap = EventNoteMap()
  @State private var frames: [CGRect] = Array(repeating: .zero, count: 128)
  @Environment(\.keyboardKeyHeight) private var keyboardKeyHeight
  @Environment(\.keyboardKeyWidth) private var keyboardKeyWidth
  @Environment(\.keyboardKeyLabel) private var keyboardKeyLabel
  @Environment(\.keyboardFixed) private var keyboardFixed
  
  private let whiteKeySpacing = 2.0

  public init(store: StoreOf<KeyboardFeature>) {
    self.store = store
  }

  public var body: some View {
    if keyboardFixed {
      fixedKeys
    } else {
      scrollingKeys
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
        frames[note.midiNoteValue] = $0
      }
  }

  private var blackKeys: some View {
    let blackKeyWidth: Double = keyboardKeyWidth * 0.75
    let offset = blackKeyWidth / 2.0
    let spacing = keyboardKeyWidth + whiteKeySpacing - blackKeyWidth
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
      .opacity(note.midiNoteValue < 0 ? 0.0 : 1)
      .onGeometryChange(for: CGRect.self) {
        $0.frame(in: .global)
      } action: {
        if (note.midiNoteValue > 0) {
          frames[note.midiNoteValue] = $0
        }
      }
  }

  private func key(note: Note) -> some View {
    let color: Color = note.accented ? .black : .white
    let width: Double = note.accented ? keyboardKeyWidth * 0.75 : keyboardKeyWidth
    let height: Double = note.accented ? keyboardKeyHeight * 0.6 : keyboardKeyHeight
    let cornerRadius: Double = 8

    return RoundedRectangle(cornerRadius: cornerRadius)
      .fill(color)
      .fill(eventNoteMap.isOn(note) ? Color.green.opacity(0.5) : .clear)
      .frame(width: width, height: height + cornerRadius)
      .offset(y: -cornerRadius)
  }

  private func labeledKey(note: Note) -> some View {
    key(note: note)
      .overlay(alignment: .bottom) {
        if (keyboardKeyLabel == .all && !note.accented) || (keyboardKeyLabel == .cOnly && note.noteIndex == 0) {
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
    let update = eventNoteMap.assign(event: event, note: note, fixedKeys: keyboardFixed)
    if update.0 != nil || update.1 {
      store.send(.assigned(previous: update.0, note: note))
    }
  }

  private func forgetNote(for event: Event) {
    if let note = eventNoteMap.release(event: event) {
      store.send(.released(note: note))
    }
  }
}

extension RandomAccessCollection where Element == CGRect {

  /**
   Obtain the index of the key in the collection that corresponds to the given position. Performs a binary search to
   locate the best candidate.

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

    // Don't continue if referencing an accented note -- we have what we want
    let key = Note(midiNoteValue: distance(from: startIndex, to: low))
    guard !key.accented else { return low }

    // Point is in the region of a white key. Check if previous or next key is accented and has the point to handle the
    // overlap of the black keys on the white ones.

    let next = index(after: low)
    if next != endIndex && Note(midiNoteValue: key.midiNoteValue + 1).accented && self[next].contains(point) {
      return next
    }

    let prev = index(before: low)
    if prev >= startIndex && Note(midiNoteValue: key.midiNoteValue - 1).accented && self[prev].contains(point) {
      return prev
    }

    return low
  }
}

struct KeyboardPreview: View {
  @State private var keyWidth: CGFloat = 64
  @State private var fixed: Bool = false
  @State private var labels: KeyboardKeyLabel = .cOnly

  var body: some View {
    VStack {
      ScrollView(.horizontal) {
        KeyboardView(store: Store(initialState: .init()) { KeyboardFeature() })
          .keyboardKeyWidth(keyWidth.rounded())
          .keyboardFixed(fixed)
          .keyboardKeyLabel(labels)
      }
      Slider(value: $keyWidth, in: 32...96)
      Text("\(Int(keyWidth.rounded()))")
      Toggle(isOn: $fixed) { Text("Fixed") }
      HStack {
        Text("Labels")
        Picker(selection: $labels) {
          Text("None").tag(KeyboardKeyLabel.none)
          Text("C Keys").tag(KeyboardKeyLabel.cOnly)
          Text("All").tag(KeyboardKeyLabel.all)
        } label: {
          Text("Labels")
        }
      }
    }
  }
}

#Preview {
  KeyboardPreview()
}
