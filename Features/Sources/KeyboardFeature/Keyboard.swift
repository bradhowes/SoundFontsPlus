// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import Dependencies
import Extensions
import SwiftUI
import Utils

public struct OctaveView: View {
  typealias Event = SpatialEventGesture.Value.Element

  public let whiteNotes: [Note] = .init(WhiteKeySequenceGenerator().makeIterator())
  public let blackNotes: [Note] = .init(BlackKeySequenceGenerator().makeIterator())

  @State private var frames: [CGRect] = Array(repeating: .zero, count: 128)
  @State private var eventNoteMap = EventNoteMap()
  @Environment(\.keyboardKeyWidth) private var keyboardKeyWidth

  public init() {}

  public var body: some View {
    whiteKeys
      .overlay(alignment: .topLeading) {
        blackKeys
      }
      .highPriorityGesture(SpatialEventGesture(coordinateSpace: .global)
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
      )
  }

  private var whiteKeys: some View {
    HStack(alignment: .top, spacing: 2){
      ForEach(0..<75) { noteIndex in
        whiteKey(note: whiteNotes[noteIndex])
      }
    }
  }

  private func whiteKey(note: Note) -> some View {
    key(note: note)
      .onGeometryChange(for: CGRect.self) {
        $0.frame(in: .global)
      } action: {
        frames[note.midiNoteValue] = $0
      }
  }

  private var blackKeys: some View {
    HStack(alignment: .top, spacing: 21) {
      Color(.clear)
        .frame(width: 22)
      ForEach(0..<74) { noteIndex in
        blackKey(note: blackNotes[noteIndex])
      }
    }
  }

  private func blackKey(note: Note) -> some View {
    key(note: note)
      .opacity(note.midiNoteValue < 0 ? 0.2 : 1)
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
    let width: Double = note.accented ? keyboardKeyWidth * 0.7 : keyboardKeyWidth
    let height: Double = note.accented ? 220 * 0.6 : 220

    return RoundedRectangle(cornerRadius: 8)
      .fill(color)
      .fill(eventNoteMap.isOn(note) ? Color.green.opacity(0.5) : .clear)
      .frame(width: width, height: height)
  }

  private func assignNote(to event: Event) {
    let pos = frames.orderedInsertionIndex(for: event.location)
    guard pos < frames.endIndex else { return }
    let note = Note(midiNoteValue: frames.distance(from: frames.startIndex, to: pos))
    let (prev, added) = eventNoteMap.assign(event: event, note: note)
    if added {
      if prev != note {
        print("assignNote:", note, "prev:", prev ?? "nil")
      }
      return
    }
  }

  private func forgetNote(for event: Event) {
    let note = eventNoteMap.release(event: event)
    print("releaseNote:", note ?? "nil")
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

extension OctaveView {
  static var preview: some View {
    ScrollView(.horizontal) {
      OctaveView()
    }
  }
}

#Preview {
  OctaveView.preview
}
