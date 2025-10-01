import Testing

@testable import SoundFontsPlus

struct KeyLabelsTests {

  @Test func attributes() async throws {
    #expect(KeyLabels.none.id.rawValue == "Off")
    #expect(KeyLabels.cOnly.id.rawValue == "C")
    #expect(KeyLabels.all.id.rawValue == "All")
    #expect(KeyLabels.none.cOnly == false)
    #expect(KeyLabels.none.all == false)
    #expect(KeyLabels.cOnly.cOnly == true)
    #expect(KeyLabels.cOnly.all == false)
    #expect(KeyLabels.all.cOnly == false)
    #expect(KeyLabels.all.all == true)
  }

}
