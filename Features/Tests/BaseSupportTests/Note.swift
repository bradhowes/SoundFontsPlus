// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import Testing

@testable import BaseSupport

struct NoteTests {

  @Test
  func initCheck() async throws {
    #expect(Note(midiNoteValue: 60).midiNoteValue == 60)
    #expect(Note(midiNoteValue: 60).label == "C4")
    #expect(Note(midiNoteValue: 0).label == "C-1")
    #expect(Note(midiNoteValue: 127).label == "G9")
  }

  @Test
  func rawRepresentable() async throws {
    #expect(Note(rawValue: "") == nil)
    #expect(Note(rawValue: "C") == nil)
    #expect(Note(rawValue: "C1234") == nil)
    #expect(Note(rawValue: "12") == nil)
    #expect(Note(rawValue: "CC") == nil)
    #expect(Note(rawValue: "C-") == nil)
    #expect(Note(rawValue: "c") == nil)
    #expect(Note(rawValue: "Z") == nil)
    #expect(Note(rawValue: "Ca1") == nil)
    #expect(Note(rawValue: "Cbb1") == nil)
    #expect(Note(rawValue: "Cb-1") == nil)
    #expect(Note(rawValue: "G#9") == nil)

    #expect(Note(rawValue: "C-1")?.midiNoteValue == 0)
    #expect(Note(rawValue: "C#-1")?.midiNoteValue == 1)
    #expect(Note(rawValue: "Gb9")?.midiNoteValue == 126)
    #expect(Note(rawValue: "G9")?.midiNoteValue == 127)

    #expect(Note(rawValue: "C4") == Note(midiNoteValue: 60))
    #expect(Note(rawValue: "C4") == .C4)
  }

  @Test
  func noteIndex() async throws {
    #expect(Note(rawValue: "C-1")?.noteIndex == 0)
    #expect(Note(rawValue: "C0")?.noteIndex == 0)
    #expect(Note(rawValue: "C9")?.noteIndex == 0)
    #expect(Note(rawValue: "C#-1")?.noteIndex == 1)
    #expect(Note(rawValue: "Gb9")?.noteIndex == 6)
    #expect(Note(rawValue: "G9")?.noteIndex == 7)
    #expect(Note(rawValue: "B8")?.noteIndex == 11)
  }

  @Test
  func accented() async throws {
    #expect(Note(midiNoteValue: 58).accented == true)
    #expect(Note(midiNoteValue: 59).accented == false)
    #expect(Note(midiNoteValue: 60).accented == false)
    #expect(Note(midiNoteValue: 61).accented == true)
  }

  @Test
  func labels() async throws {
    #expect(Note(midiNoteValue: 49).labelWithSharps == "C♯3")
    #expect(Note(midiNoteValue: 51).labelWithSharps == "D♯3")
    #expect(Note(midiNoteValue: 54).labelWithSharps == "F♯3")
    #expect(Note(midiNoteValue: 56).labelWithSharps == "G♯3")
    #expect(Note(midiNoteValue: 58).labelWithSharps == "A♯3")

    #expect(Note(midiNoteValue: 49).labelWithFlats == "D♭3")
    #expect(Note(midiNoteValue: 51).labelWithFlats == "E♭3")
    #expect(Note(midiNoteValue: 54).labelWithFlats == "G♭3")
    #expect(Note(midiNoteValue: 56).labelWithFlats == "A♭3")
    #expect(Note(midiNoteValue: 58).labelWithFlats == "B♭3")

    #expect(Note(midiNoteValue: 58).description == "A♯3")

    #expect(Note(midiNoteValue: 48).fullLabel(withSolfege: false) == "C3")
    #expect(Note(midiNoteValue: 48).fullLabel(withSolfege: true) == "C3 (Do)")
    #expect(Note(midiNoteValue: 49).fullLabel(withSolfege: true) == "C♯3 (Do)")
  }

  @Test
  func offset() async throws {
    #expect(Note(midiNoteValue: 49).offset(-1).labelWithSharps == "C3")
    #expect(Note(midiNoteValue: 49).offset(1).labelWithSharps == "D3")
    #expect(Note(midiNoteValue: 49).offset(2).labelWithSharps == "D♯3")
  }

  @Test
  func ID() async throws {
    #expect(Note(midiNoteValue: 49).id == 49)
  }

  @Test
  func queryBinding() async throws {
    #expect(Note(midiNoteValue: 49).queryBinding.debugDescription == "'\(Note(midiNoteValue: 49).label)'")
  }

  @Test
  func phantomNotes() async throws {
    #expect(Note(midiNoteValue: 58).isPhantomNote == false)
    #expect(Note.phantomNote.isPhantomNote == true)
    #expect(Note.phantomNote.isValidMidiNote == false)
  }

  @Test
  func solfege() async throws {
    #expect(Note(midiNoteValue: 60).solfege == "Do")
    #expect(Note(midiNoteValue: 61).solfege == "Do")
    #expect(Note(midiNoteValue: 62).solfege == "Re")
    #expect(Note(midiNoteValue: 63).solfege == "Re")
    #expect(Note(midiNoteValue: 64).solfege == "Mi")
    #expect(Note(midiNoteValue: 65).solfege == "Fa")
    #expect(Note(midiNoteValue: 66).solfege == "Fa")
    #expect(Note(midiNoteValue: 67).solfege == "Sol")
    #expect(Note(midiNoteValue: 68).solfege == "Sol")
    #expect(Note(midiNoteValue: 69).solfege == "La")
    #expect(Note(midiNoteValue: 70).solfege == "La")
    #expect(Note(midiNoteValue: 71).solfege == "Ti")
  }

  @Test
  func comparisons() async throws {
    #expect(Note(midiNoteValue: 60) == Note(midiNoteValue: 60))
    #expect(Note(midiNoteValue: 60) <= Note(midiNoteValue: 60))
    #expect(!(Note(midiNoteValue: 60) < Note(midiNoteValue: 60)))
    #expect(Note(midiNoteValue: 60) != Note(midiNoteValue: 61))
    #expect(Note(midiNoteValue: 60) < Note(midiNoteValue: 61))
    #expect(!(Note(midiNoteValue: 61) < Note(midiNoteValue: 60)))
  }

  @Test
  func hashing() async throws {
    var hasher1 = Hasher()
    hasher1.combine(60)
    hasher1.combine(61)
    hasher1.combine(62)

    var hasher2 = Hasher()
    Note(midiNoteValue: 60).hash(into: &hasher2)
    Note(midiNoteValue: 61).hash(into: &hasher2)
    Note(midiNoteValue: 62).hash(into: &hasher2)

    #expect(hasher1.finalize() == hasher2.finalize())
  }

  @Test
  func range() throws {
    #expect((Note(midiNoteValue: 60)...Note(midiNoteValue: 60)).count == 1)
    #expect((Note(midiNoteValue: 60)..<Note(midiNoteValue: 61)).count == 1)
    #expect((Note(midiNoteValue: 60)...Note(midiNoteValue: 70)).count == 11)
    #expect(Note(midiNoteValue: 60).advanced(by: 3) == Note(midiNoteValue: 63))
  }

  @Test
  func constants() throws {
    #expect(Note.`C-1`.midiNoteValue == 0)
    #expect(Note.`D-1`.midiNoteValue == 2)
    #expect(Note.`E-1`.midiNoteValue == 4)
    #expect(Note.`F-1`.midiNoteValue == 5)
    #expect(Note.`G-1`.midiNoteValue == 7)
    #expect(Note.`A-1`.midiNoteValue == 9)
    #expect(Note.`B-1`.midiNoteValue == 11)

    #expect(Note.C0.midiNoteValue == 12)
    #expect(Note.D0.midiNoteValue == 14)
    #expect(Note.E0.midiNoteValue == 16)
    #expect(Note.F0.midiNoteValue == 17)
    #expect(Note.G0.midiNoteValue == 19)
    #expect(Note.A0.midiNoteValue == 21)
    #expect(Note.B0.midiNoteValue == 23)

    #expect(Note.C1.midiNoteValue == 24)
    #expect(Note.D1.midiNoteValue == 26)
    #expect(Note.E1.midiNoteValue == 28)
    #expect(Note.F1.midiNoteValue == 29)
    #expect(Note.G1.midiNoteValue == 31)
    #expect(Note.A1.midiNoteValue == 33)
    #expect(Note.B1.midiNoteValue == 35)

    #expect(Note.C2.midiNoteValue == 36)
    #expect(Note.D2.midiNoteValue == 38)
    #expect(Note.E2.midiNoteValue == 40)
    #expect(Note.F2.midiNoteValue == 41)
    #expect(Note.G2.midiNoteValue == 43)
    #expect(Note.A2.midiNoteValue == 45)
    #expect(Note.B2.midiNoteValue == 47)

    #expect(Note.C3.midiNoteValue == 48)
    #expect(Note.D3.midiNoteValue == 50)
    #expect(Note.E3.midiNoteValue == 52)
    #expect(Note.F3.midiNoteValue == 53)
    #expect(Note.G3.midiNoteValue == 55)
    #expect(Note.A3.midiNoteValue == 57)
    #expect(Note.B3.midiNoteValue == 59)

    #expect(Note.C4.midiNoteValue == 60)
    #expect(Note.D4.midiNoteValue == 62)
    #expect(Note.E4.midiNoteValue == 64)
    #expect(Note.F4.midiNoteValue == 65)
    #expect(Note.G4.midiNoteValue == 67)
    #expect(Note.A4.midiNoteValue == 69)
    #expect(Note.B4.midiNoteValue == 71)

    #expect(Note.C5.midiNoteValue == 72)
    #expect(Note.D5.midiNoteValue == 74)
    #expect(Note.E5.midiNoteValue == 76)
    #expect(Note.F5.midiNoteValue == 77)
    #expect(Note.G5.midiNoteValue == 79)
    #expect(Note.A5.midiNoteValue == 81)
    #expect(Note.B5.midiNoteValue == 83)

    #expect(Note.C6.midiNoteValue == 84)
    #expect(Note.D6.midiNoteValue == 86)
    #expect(Note.E6.midiNoteValue == 88)
    #expect(Note.F6.midiNoteValue == 89)
    #expect(Note.G6.midiNoteValue == 91)
    #expect(Note.A6.midiNoteValue == 93)
    #expect(Note.B6.midiNoteValue == 95)

    #expect(Note.C7.midiNoteValue == 96)
    #expect(Note.D7.midiNoteValue == 98)
    #expect(Note.E7.midiNoteValue == 100)
    #expect(Note.F7.midiNoteValue == 101)
    #expect(Note.G7.midiNoteValue == 103)
    #expect(Note.A7.midiNoteValue == 105)
    #expect(Note.B7.midiNoteValue == 107)

    #expect(Note.C8.midiNoteValue == 108)
    #expect(Note.D8.midiNoteValue == 110)
    #expect(Note.E8.midiNoteValue == 112)
    #expect(Note.F8.midiNoteValue == 113)
    #expect(Note.G8.midiNoteValue == 115)
    #expect(Note.A8.midiNoteValue == 117)
    #expect(Note.B8.midiNoteValue == 119)

    #expect(Note.C9.midiNoteValue == 120)
    #expect(Note.D9.midiNoteValue == 122)
    #expect(Note.E9.midiNoteValue == 124)
    #expect(Note.F9.midiNoteValue == 125)
    #expect(Note.G9.midiNoteValue == 127)
  }
}
