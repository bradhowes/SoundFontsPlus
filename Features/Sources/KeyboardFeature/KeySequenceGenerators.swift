// Copyright © 2025 Brad Howes. All rights reserved.

import Algorithms
import Foundation
import Utils

/// Generate a sequence of MIDI values for the white keys. Generates up to MIDI note 127.
public struct WhiteKeySequenceGenerator: Sequence, IteratorProtocol {
  private var deltas = [2, 2, 1, 2, 2, 2, 1].cycled().makeIterator()
  private var nextMidiNote: Int = 0

  @inlinable public func makeIterator() -> WhiteKeySequenceGenerator { self }

  public mutating func next() -> Note? {
    guard nextMidiNote <= 127 else { return nil }
    let note = Note(midiNoteValue: nextMidiNote)
    nextMidiNote += deltas.next()!
    return note
  }

  public var whiteKeyNotes: [Note] {
    [Note](WhiteKeySequenceGenerator().makeIterator())
  }
}

/// Generate a sequence of MIDI values for the black keys. Generates up to MIDI note 127.
/// NOTE: generates "phantom" MIDI keys that are negative which are used by the SwifUI code to
/// draw an invisible key at E# and B#.
public struct BlackKeySequenceGenerator: Sequence, IteratorProtocol {
  private var deltas = [2, 3, 0, 2, 2, 3, 0].cycled().makeIterator()
  private var nextMidiNote: Int = 1

  @inlinable public func makeIterator() -> BlackKeySequenceGenerator { self }

  public mutating func next() -> Note? {
    guard nextMidiNote < 127 else { return nil }
    let delta = deltas.next()!
    let note = Note(midiNoteValue: delta > 0 ? nextMidiNote : -nextMidiNote)
    nextMidiNote += delta
    return note
  }
}
