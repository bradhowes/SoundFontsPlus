// Copyright © 2025 Brad Howes. All rights reserved.

import StructuredQueries

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

  public static var sharpTag: String { "♯" }
  public static var flatTag: String { "♭" }

  public static var sharpTags: [Character] { [Character(sharpTag), "#"] }
  public static var flatTags: [Character] { [Character(flatTag), "b"] }

  /// Collection of an octave of note labels that uses sharps for accidentals.
  public static var labelsWithSharps: [String] {
    [
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
  }

  /// Collection of an octave of note labels that uses flats for accidentals.
  public static var labelsWithFlats: [String] {
    [
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
  }

  /// Collection of solfege labels. There are many variations. This one is what is found in "The Sound of Music".
  public static var solfegeLabels: [String] {
    [
      "Do", "Do", "Re", "Re", "Mi", "Fa", "Fa", "Sol", "Sol", "La", "La", "Ti"
    ]
  }

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

  public static let lowest = Note(midiNoteValue: midiRange.lowerBound)
  public static let highest = Note(midiNoteValue: midiRange.upperBound)

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

extension Note: Identifiable {
  public typealias ID = Int

  public var id: ID { midiNoteValue }
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

  public func fullLabel(withSolfege: Bool) -> String {
    self.label + (withSolfege ? " (\(self.solfege))" : "")
  }
}

extension Note: Comparable {
  public static func < (lhs: Note, rhs: Note) -> Bool { lhs.midiNoteValue < rhs.midiNoteValue }
  public static func == (lhs: Note, rhs: Note) -> Bool { lhs.midiNoteValue == rhs.midiNoteValue }
}

extension Note: Hashable {
  public func hash(into hasher: inout Hasher) { hasher.combine(midiNoteValue) }
}

extension Note: QueryBindable {
  public var queryBinding: QueryBinding { .text(rawValue) }
}

extension Note: Strideable {
  public func distance(to other: Note) -> Int { other.midiNoteValue - midiNoteValue }
  public func advanced(by delta: Int) -> Note { .init(midiNoteValue: midiNoteValue + delta) }
}

extension Note {

  // swiftlint:disable identifier_name
  public static var `C-1`: Note { .init(midiNoteValue: 0) }
  public static var `D-1`: Note { .init(midiNoteValue: 2) }
  public static var `E-1`: Note { .init(midiNoteValue: 4) }
  public static var `F-1`: Note { .init(midiNoteValue: 5) }
  public static var `G-1`: Note { .init(midiNoteValue: 7) }
  public static var `A-1`: Note { .init(midiNoteValue: 9) }
  public static var `B-1`: Note { .init(midiNoteValue: 11) }
  // swiftlint:enable identifier_name

  public static var C0: Note { .init(midiNoteValue: 12) }
  public static var D0: Note { .init(midiNoteValue: 14) }
  public static var E0: Note { .init(midiNoteValue: 16) }
  public static var F0: Note { .init(midiNoteValue: 17) }
  public static var G0: Note { .init(midiNoteValue: 19) }
  public static var A0: Note { .init(midiNoteValue: 21) }
  public static var B0: Note { .init(midiNoteValue: 23) }

  public static var C1: Note { .init(midiNoteValue: 24) }
  public static var D1: Note { .init(midiNoteValue: 26) }
  public static var E1: Note { .init(midiNoteValue: 28) }
  public static var F1: Note { .init(midiNoteValue: 29) }
  public static var G1: Note { .init(midiNoteValue: 31) }
  public static var A1: Note { .init(midiNoteValue: 33) }
  public static var B1: Note { .init(midiNoteValue: 35) }

  public static var C2: Note { .init(midiNoteValue: 36) }
  public static var D2: Note { .init(midiNoteValue: 38) }
  public static var E2: Note { .init(midiNoteValue: 40) }
  public static var F2: Note { .init(midiNoteValue: 41) }
  public static var G2: Note { .init(midiNoteValue: 43) }
  public static var A2: Note { .init(midiNoteValue: 45) }
  public static var B2: Note { .init(midiNoteValue: 47) }

  public static var C3: Note { .init(midiNoteValue: 48) }
  public static var D3: Note { .init(midiNoteValue: 50) }
  public static var E3: Note { .init(midiNoteValue: 52) }
  public static var F3: Note { .init(midiNoteValue: 53) }
  public static var G3: Note { .init(midiNoteValue: 55) }
  public static var A3: Note { .init(midiNoteValue: 57) }
  public static var B3: Note { .init(midiNoteValue: 59) }

  public static var C4: Note { .init(midiNoteValue: 60) }
  public static var D4: Note { .init(midiNoteValue: 62) }
  public static var E4: Note { .init(midiNoteValue: 64) }
  public static var F4: Note { .init(midiNoteValue: 65) }
  public static var G4: Note { .init(midiNoteValue: 67) }
  public static var A4: Note { .init(midiNoteValue: 69) }
  public static var B4: Note { .init(midiNoteValue: 71) }

  public static var C5: Note { .init(midiNoteValue: 72) }
  public static var D5: Note { .init(midiNoteValue: 74) }
  public static var E5: Note { .init(midiNoteValue: 76) }
  public static var F5: Note { .init(midiNoteValue: 77) }
  public static var G5: Note { .init(midiNoteValue: 79) }
  public static var A5: Note { .init(midiNoteValue: 81) }
  public static var B5: Note { .init(midiNoteValue: 83) }

  public static var C6: Note { .init(midiNoteValue: 84) }
  public static var D6: Note { .init(midiNoteValue: 86) }
  public static var E6: Note { .init(midiNoteValue: 88) }
  public static var F6: Note { .init(midiNoteValue: 89) }
  public static var G6: Note { .init(midiNoteValue: 91) }
  public static var A6: Note { .init(midiNoteValue: 93) }
  public static var B6: Note { .init(midiNoteValue: 95) }

  public static var C7: Note { .init(midiNoteValue: 96) }
  public static var D7: Note { .init(midiNoteValue: 98) }
  public static var E7: Note { .init(midiNoteValue: 100) }
  public static var F7: Note { .init(midiNoteValue: 101) }
  public static var G7: Note { .init(midiNoteValue: 103) }
  public static var A7: Note { .init(midiNoteValue: 105) }
  public static var B7: Note { .init(midiNoteValue: 107) }

  public static var C8: Note { .init(midiNoteValue: 108) }
  public static var D8: Note { .init(midiNoteValue: 110) }
  public static var E8: Note { .init(midiNoteValue: 112) }
  public static var F8: Note { .init(midiNoteValue: 113) }
  public static var G8: Note { .init(midiNoteValue: 115) }
  public static var A8: Note { .init(midiNoteValue: 117) }
  public static var B8: Note { .init(midiNoteValue: 119) }

  public static var C9: Note { .init(midiNoteValue: 120) }
  public static var D9: Note { .init(midiNoteValue: 122) }
  public static var E9: Note { .init(midiNoteValue: 124) }
  public static var F9: Note { .init(midiNoteValue: 125) }
  public static var G9: Note { .init(midiNoteValue: 127) }
}
