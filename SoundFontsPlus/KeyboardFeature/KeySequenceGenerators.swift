// Copyright © 2025 Brad Howes. All rights reserved.

import Algorithms
import Foundation

/// Generate a sequence of MIDI values for the white keys. Generates up to MIDI note 127.
public struct WhiteKeySequenceGenerator: Sequence, IteratorProtocol {
  // Number of note steps to move to the next unaccented note
  private var steps = [2, 2, 1, 2, 2, 2, 1].cycled().makeIterator()
  private var nextMidiNote: Int = Note.midiRange.lowerBound

  @inlinable public func makeIterator() -> WhiteKeySequenceGenerator { self }

  public mutating func next() -> Note? {
    guard
      nextMidiNote <= Note.midiRange.upperBound,
      let step = steps.next()
    else {
      return nil
    }

    let note = Note(midiNoteValue: nextMidiNote)
    nextMidiNote += step
    return note
  }

  public var whiteKeyNotes: [Note] {
    [Note](WhiteKeySequenceGenerator().makeIterator())
  }
}

/**
 Generate a sequence of MIDI values for the black keys. Generates up to MIDI note 127.
 NOTE: generates "phantom" MIDI keys that used by the Keyboard code to draw an invisible key at E# and B#.
 Consumers of this Note sequence must account for these in the stream.
 */
public struct BlackKeySequenceGenerator: Sequence, IteratorProtocol {
  // Number of note steps to move to the next accented note
  private var steps = [2, 3, 0, 2, 2, 3, 0].cycled().makeIterator()
  private var nextMidiNote: Int = Note.midiRange.lowerBound + 1

  @inlinable public func makeIterator() -> BlackKeySequenceGenerator { self }

  public mutating func next() -> Note? {
    guard
      nextMidiNote <= Note.midiRange.upperBound,
      let step = steps.next()
    else {
      return nil
    }

    let note = step > 0 ? Note(midiNoteValue: nextMidiNote) : Note.phantomNote
    nextMidiNote += step
    return note
  }
}
