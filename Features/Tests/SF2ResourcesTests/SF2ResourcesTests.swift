// Copyright © 2025 Brad Howes. All rights reserved.

import Engine
import Foundation
import Testing

@testable import SF2Resources

@Suite
struct SF2ResourcesTests {

  @Test
  func resourcesExist() throws {
    #expect(SF2Resource.resources.count == 4)
    for url in SF2Resource.resources {
      #expect(try url.checkResourceIsReachable() == true)
    }
  }

  @Test
  func resourceByFileName() throws {
    for name in ["RolandNicePiano", "FreeFont", "GeneralUser GS MuseScore v1.442"] {
      let url = try SF2Resource.resource(fileName: name)
      #expect(try url.checkResourceIsReachable())
    }
    #expect(throws: SF2ResourceError.notFound(name: "THIS DOES NOT EXIST")) {
      try SF2Resource.resource(fileName: "THIS DOES NOT EXIST")
    }
  }

  @Test
  func resourceByTag() throws {
    for tag in SF2ResourceTag.allCases {
      let url = SF2Resource.resources[tag.resourceIndex]
      #expect(url == tag.url)
      #expect(try url.checkResourceIsReachable())
    }
  }

  @Test
  func resourceNames() throws {
    #expect(SF2ResourceTag.fluidFont.name == "Fluid R3")
    #expect(SF2ResourceTag.freeFont.name == "FreeFont")
    #expect(SF2ResourceTag.museScore.name == "MuseScore")
    #expect(SF2ResourceTag.rolandNicePiano.name == "Roland Piano")
  }

  @Test
  func fluidFontFileInfo() throws {
    // swiftlint:disable:next force_unwrapping
    let fileInfo = SF2ResourceTag.fluidFont.fileInfo!
    #expect(fileInfo.embeddedName() == "Fluid R3 GM")
    #expect(fileInfo.embeddedAuthor() == "Frank Wen")
    #expect(fileInfo.embeddedComment() == "")
    #expect(fileInfo.embeddedCopyright() == "Frank Wen 2000-2002")
    #expect(fileInfo.size() == 189)
  }

  @Test
  func freeFontFileInfo() throws {
    // swiftlint:disable:next force_unwrapping
    let fileInfo = SF2ResourceTag.freeFont.fileInfo!
    #expect(fileInfo.embeddedName() == "Free Font GM Ver. 3.2")
    #expect(fileInfo.embeddedAuthor() == "")
    #expect(fileInfo.embeddedComment() == "")
    #expect(fileInfo.embeddedCopyright() == "")

    #expect(fileInfo.size() == 235)
    var presetInfo = fileInfo[0]
    #expect(presetInfo.name() == "Piano 1")
    #expect(presetInfo.bank() == 0)
    #expect(presetInfo.program() == 0)
    presetInfo = fileInfo[1]
    #expect(presetInfo.name() == "Piano 2")
    #expect(presetInfo.bank() == 0)
    #expect(presetInfo.program() == 1)
    presetInfo = fileInfo[2]
    #expect(presetInfo.name() == "Piano 3")
    #expect(presetInfo.bank() == 0)
    #expect(presetInfo.program() == 2)
    presetInfo = fileInfo[fileInfo.size() - 1]
    #expect(presetInfo.name() == "SFX")
    #expect(presetInfo.bank() == 128)
    #expect(presetInfo.program() == 56)
  }

  @Test
  func rolandNicePianoFileInfo() throws {
    // swiftlint:disable:next force_unwrapping
    let fileInfo = SF2ResourceTag.rolandNicePiano.fileInfo!
    #expect(fileInfo.embeddedName() == "User Bank")
    #expect(fileInfo.embeddedAuthor() == "Vienna Master")
    #expect(fileInfo.embeddedComment() == "Comments Not Present")
    #expect(fileInfo.embeddedCopyright() == "Copyright Information Not Present")

    #expect(fileInfo.size() == 1)
    let presetInfo = fileInfo[0]
    #expect(presetInfo.name() == "Nice Piano")
    #expect(presetInfo.bank() == 0)
    #expect(presetInfo.program() == 1)
  }

  @Test
  func museScoreFileInfo() throws {
    // swiftlint:disable:next force_unwrapping
    let fileInfo = SF2ResourceTag.museScore.fileInfo!
    #expect(fileInfo.embeddedName() == "GeneralUser GS MuseScore version 1.442")
    #expect(fileInfo.embeddedAuthor() == "S. Christian Collins")
    #expect(fileInfo.embeddedComment() != "")
    #expect(fileInfo.embeddedCopyright() == "2012 by S. Christian Collins")

    #expect(fileInfo.size() == 270)
    var presetInfo = fileInfo[0]
    #expect(presetInfo.name() == "Stereo Grand")
    #expect(presetInfo.bank() == 0)
    #expect(presetInfo.program() == 0)
    presetInfo = fileInfo[1]
    #expect(presetInfo.name() == "Bright Grand")
    #expect(presetInfo.bank() == 0)
    #expect(presetInfo.program() == 1)
    presetInfo = fileInfo[2]
    #expect(presetInfo.name() == "Electric Grand")
    #expect(presetInfo.bank() == 0)
    #expect(presetInfo.program() == 2)
    presetInfo = fileInfo[fileInfo.size() - 1]
    #expect(presetInfo.name() == "SFX")
    #expect(presetInfo.bank() == 128)
    #expect(presetInfo.program() == 56)
  }
}
