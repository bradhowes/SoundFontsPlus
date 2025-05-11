// Copyright © 2025 Brad Howes. All rights reserved.

// import Foundation

/**
 Definition of a MIDI v1 note where the MIDI value is in range [0-127].

 Supports conversion from a string representation. According to https://computermusicresource.com/midikeys.html there
 are two standards for octave designation:

 * MIDI 60 is "C3" -- most MIDI standard keyboards (according to link above) (min octave is -2)
 * MIDI 60 is "C4" -- Yamaha and the Octave Designation System in music education (min octave is -1)

 We are using the second one below in the RawRepresentable decoding, but the app in general supports both for display
 purposes.
 */
public struct Note: CustomStringConvertible, Sendable {

  public static let C4 = Note(midiNoteValue: 60)
  public static let A4 = Note(midiNoteValue: 69)

  public static let sharpTag = "♯"
  public static let flatTag = "♭"

  public static let sharpTags: [Character] = [Character(sharpTag), "#"]
  public static let flatTags: [Character] = [Character(flatTag), "b"]

  /// Collection of an octave of note labels that uses sharps for accidentals.
  public static let labelsWithSharps: [String] = [
    "C",
    "C" + sharpTag,
    "D",
    "D" + sharpTag,
    "E",
    "F",
    "F" + sharpTag,
    "G",
    "G" + sharpTag,
    "A",
    "A" + sharpTag,
    "B"
  ]

  /// Collection of an octave of note labels that uses flats for accidentals.
  public static let labelsWithFlats: [String] = [
    "C",
    "D" + flatTag,
    "D",
    "E" + flatTag,
    "E",
    "F",
    "G" + flatTag,
    "G",
    "A" + flatTag,
    "A",
    "B" + flatTag,
    "B"
  ]

  /// Collection of solfege labels. There are many variations. This one is what is found in "The Sound of Music".
  public static let solfegeLabels: [String] = [
    "Do", "Do", "Re", "Re", "Mi", "Fa", "Fa", "Sol", "Sol", "La", "La", "Ti"
  ]

  /// Collection of note indices that are accented notes
  public static let accentedIndices: Set<Int> = [1, 3, 6, 8, 10]

  /// The MIDI value to emit to generate this note
  public let midiNoteValue: Int

  /// The note index where C is 0, C# is 1, and B is 11
  public let noteIndex: Int

  /// True if this note is accented (sharp or flat)
  public var accented: Bool { Note.accentedIndices.contains(noteIndex) }

  /// Obtain a textual representation of the note that uses sharps for accidentals
  public var labelWithSharps: String { Note.labelsWithSharps[noteIndex] + "\(octave)" }

  /// Obtain a textual representation of the note that uses flats for accidentals
  public var labelWithFlats: String { Note.labelsWithFlats[noteIndex] + "\(octave)" }

  /// Obtain a textual representation of the note that uses sharps for accidentals
  public var label: String { Note.labelsWithSharps[noteIndex] + "\(octave)" }

  /// Obtain the solfege representation for this note
  public var solfege: String { Note.solfegeLabels[noteIndex] }

  /// Obtain the octave this note is a part of
  public var octave: Int { midiNoteValue / 12 - 1 }

  /// Custom string representation for a Note instance
  public var description: String { label }

  /// Range of valid MIDI v1 notes
  public static let midiRange: ClosedRange<Int> = 0...127

  /// @returns true if instance is a valid MIDI v1 note
  public var isValidMidiNote: Bool { Self.midiRange.contains(midiNoteValue) }

  /**
   Create new Note instance using an unchecked rawValue

   - parameter rawValue: MIDI note value for this instance (may be invalid)
   */
  internal init(rawValue: Int) {
    self.midiNoteValue = rawValue
    self.noteIndex = midiNoteValue % 12
  }

  /**
   Create new Note instance.

   - parameter midiNoteValue: MIDI note value for this instance
   */
  public init(midiNoteValue: Int) {
    guard Self.midiRange.contains(midiNoteValue) else { fatalError("invalid MIDI note value") }
    self.init(rawValue: midiNoteValue)
  }
}

extension Note {
  /// NOTE: magic value. Keep as a multiple of 128 (not sure why yet).
  public static let phantomNote: Note = .init(rawValue: 12800)

  public var isPhantomNote: Bool { self.midiNoteValue == Note.phantomNote.midiNoteValue }
}

extension Note {

  public func offset(_ semitones: Int) -> Note {
    return Note(midiNoteValue: self.midiNoteValue + semitones)
  }
}

extension Note: RawRepresentable {
  public typealias RawValue = String

  public var rawValue: String { description }

  /**
   Convert string representation into a Note instance. Valid strings contain

   * a note value in `ABCDEFG`
   * optional accidental tag in `b♭#♯`
   * octave integer in range [-1, 9]

   The resulting MIDI value must be in range [0, 127]

   - parameter tag: the tag to convert
   */
  public init?(rawValue tag: String) {
    // C♯-1, G♯9
    guard tag.count > 1 && tag.count < 5 else { return nil }
    var remaining = tag[...]

    guard let note = remaining.popFirst() else { return nil }
    guard var offset = Self.labelsWithSharps.firstIndex(of: String(note)) else { return nil }

    if let accidental = remaining.first {
      if Self.sharpTags.contains(accidental) {
        offset += 1
        remaining = remaining.dropFirst()
      } else if Self.flatTags.contains(accidental) {
        offset -= 1
        remaining = remaining.dropFirst()
      }
    }

    guard let octave = Int(remaining),
          octave >= -1,
          octave <= 9
    else {
      return nil
    }

    let midiNoteValue = (octave + 1) * 12 + offset
    guard Self.midiRange.contains(midiNoteValue) else { return nil }

    self.init(midiNoteValue: midiNoteValue)
  }
}

extension Note: Comparable {
  public static func < (lhs: Note, rhs: Note) -> Bool { lhs.midiNoteValue < rhs.midiNoteValue }
  public static func == (lhs: Note, rhs: Note) -> Bool { lhs.midiNoteValue == rhs.midiNoteValue }
}

extension Note: Hashable {
  public func hash(into hasher: inout Hasher) { hasher.combine(midiNoteValue) }
}
