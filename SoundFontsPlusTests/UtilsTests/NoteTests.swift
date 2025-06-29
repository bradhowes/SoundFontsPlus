import Testing

@testable import SoundFontsPlus

struct NoteTests {

  @Test func initCheck() async throws {
    #expect(Note(midiNoteValue: 60).midiNoteValue == 60)
    #expect(Note(midiNoteValue: 60).label == "C4")
    #expect(Note(midiNoteValue: 0).label == "C-1")
    #expect(Note(midiNoteValue: 127).label == "G9")
  }

  @Test func rawRepresentable() async throws {
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
  }

  @Test func noteIndex() async throws {
    #expect(Note(rawValue: "C-1")?.noteIndex == 0)
    #expect(Note(rawValue: "C0")?.noteIndex == 0)
    #expect(Note(rawValue: "C9")?.noteIndex == 0)
    #expect(Note(rawValue: "C#-1")?.noteIndex == 1)
    #expect(Note(rawValue: "Gb9")?.noteIndex == 6)
    #expect(Note(rawValue: "G9")?.noteIndex == 7)
    #expect(Note(rawValue: "B8")?.noteIndex == 11)
  }

  @Test func accented() async throws {
    #expect(Note(midiNoteValue: 58).accented == true)
    #expect(Note(midiNoteValue: 59).accented == false)
    #expect(Note(midiNoteValue: 60).accented == false)
    #expect(Note(midiNoteValue: 61).accented == true)
  }

  @Test func phantomNotes() async throws {
    #expect(Note(midiNoteValue: 58).isPhantomNote == false)
    #expect(Note.phantomNote.isPhantomNote == true)
    #expect(Note.phantomNote.isValidMidiNote == false)
  }

  @Test func solfege() async throws {
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

  @Test func comparisons() async throws {
    #expect(Note(midiNoteValue: 60) == Note(midiNoteValue: 60))
    #expect(Note(midiNoteValue: 60) <= Note(midiNoteValue: 60))
    #expect(!(Note(midiNoteValue: 60) < Note(midiNoteValue: 60)))
    #expect(Note(midiNoteValue: 60) != Note(midiNoteValue: 61))
    #expect(Note(midiNoteValue: 60) < Note(midiNoteValue: 61))
    #expect(!(Note(midiNoteValue: 61) < Note(midiNoteValue: 60)))
  }

  @Test func hashing() async throws {
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

  @Test func range() throws {
    #expect((Note(midiNoteValue: 60)...Note(midiNoteValue: 60)).count == 1)
    #expect((Note(midiNoteValue: 60)..<Note(midiNoteValue: 61)).count == 1)
    #expect((Note(midiNoteValue: 60)...Note(midiNoteValue: 70)).count == 11)
    #expect(Note(midiNoteValue: 60).advanced(by: 3) == Note(midiNoteValue: 63))
  }
}
