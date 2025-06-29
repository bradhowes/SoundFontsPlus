import XCTest
import Engine

@testable import SoundFontsPlus

final class SF2ResourceFilesTests: XCTestCase {

  func testResourcesExist() throws {
    XCTAssertEqual(SF2ResourceFiles.resources.count, 3)
    for url in SF2ResourceFiles.resources {
      try XCTAssertTrue(url.checkResourceIsReachable())
    }
  }

  func testResourceByFileName() throws {
    for name in ["RolandNicePiano", "FreeFont", "GeneralUser GS MuseScore v1.442"] {
      let url = try SF2ResourceFiles.resource(fileName: name)
      try XCTAssertTrue(url.checkResourceIsReachable())
    }
  }

  func testResourceByTag() throws {
    for tag in SF2ResourceFileTag.allCases {
      let url = SF2ResourceFiles.resources[tag.resourceIndex]
      XCTAssertEqual(url, tag.url)
      try XCTAssertTrue(url.checkResourceIsReachable())
    }
  }

  func testResourceNames() throws {
    XCTAssertEqual(SF2ResourceFileTag.freeFont.name, "FreeFont")
    XCTAssertEqual(SF2ResourceFileTag.museScore.name, "MuseScore")
    XCTAssertEqual(SF2ResourceFileTag.rolandNicePiano.name, "Roland Piano")
  }

  func testFreeFontFileInfo() throws {
    let fileInfo = SF2ResourceFileTag.freeFont.fileInfo!
    XCTAssertEqual(fileInfo.embeddedName(), "Free Font GM Ver. 3.2")
    XCTAssertEqual(fileInfo.embeddedAuthor(), "")
    XCTAssertEqual(fileInfo.embeddedComment(), "")
    XCTAssertEqual(fileInfo.embeddedCopyright(), "")

    XCTAssertEqual(fileInfo.size(), 235)
    var presetInfo = fileInfo[0]
    XCTAssertEqual(presetInfo.name(), "Piano 1")
    XCTAssertEqual(presetInfo.bank(), 0)
    XCTAssertEqual(presetInfo.program(), 0)
    presetInfo = fileInfo[1]
    XCTAssertEqual(presetInfo.name(), "Piano 2")
    XCTAssertEqual(presetInfo.bank(), 0)
    XCTAssertEqual(presetInfo.program(), 1)
    presetInfo = fileInfo[2]
    XCTAssertEqual(presetInfo.name(), "Piano 3")
    XCTAssertEqual(presetInfo.bank(), 0)
    XCTAssertEqual(presetInfo.program(), 2)
    presetInfo = fileInfo[fileInfo.size() - 1]
    XCTAssertEqual(presetInfo.name(), "SFX")
    XCTAssertEqual(presetInfo.bank(), 128)
    XCTAssertEqual(presetInfo.program(), 56)
  }

  func testRolandNicePianoFileInfo() throws {
    let fileInfo = SF2ResourceFileTag.rolandNicePiano.fileInfo!
    XCTAssertEqual(fileInfo.embeddedName(), "User Bank")
    XCTAssertEqual(fileInfo.embeddedAuthor(), "Vienna Master")
    XCTAssertEqual(fileInfo.embeddedComment(), "Comments Not Present")
    XCTAssertEqual(fileInfo.embeddedCopyright(), "Copyright Information Not Present")

    XCTAssertEqual(fileInfo.size(), 1)
    let presetInfo = fileInfo[0]
    XCTAssertEqual(presetInfo.name(), "Nice Piano")
    XCTAssertEqual(presetInfo.bank(), 0)
    XCTAssertEqual(presetInfo.program(), 1)
  }

  func testMuseScoreFileInfo() throws {
    let fileInfo = SF2ResourceFileTag.museScore.fileInfo!
    XCTAssertEqual(fileInfo.embeddedName(), "GeneralUser GS MuseScore version 1.442")
    XCTAssertEqual(fileInfo.embeddedAuthor(), "S. Christian Collins")
    XCTAssertNotEqual(fileInfo.embeddedComment(), "")
    XCTAssertEqual(fileInfo.embeddedCopyright(), "2012 by S. Christian Collins")

    XCTAssertEqual(fileInfo.size(), 270)
    var presetInfo = fileInfo[0]
    XCTAssertEqual(presetInfo.name(), "Stereo Grand")
    XCTAssertEqual(presetInfo.bank(), 0)
    XCTAssertEqual(presetInfo.program(), 0)
    presetInfo = fileInfo[1]
    XCTAssertEqual(presetInfo.name(), "Bright Grand")
    XCTAssertEqual(presetInfo.bank(), 0)
    XCTAssertEqual(presetInfo.program(), 1)
    presetInfo = fileInfo[2]
    XCTAssertEqual(presetInfo.name(), "Electric Grand")
    XCTAssertEqual(presetInfo.bank(), 0)
    XCTAssertEqual(presetInfo.program(), 2)
    presetInfo = fileInfo[fileInfo.size() - 1]
    XCTAssertEqual(presetInfo.name(), "SFX")
    XCTAssertEqual(presetInfo.bank(), 128)
    XCTAssertEqual(presetInfo.program(), 56)
  }
}
