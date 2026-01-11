// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
import Foundation
import SF2Resources
import SQLiteData
import Testing
import TestSupport

@testable import Models

@Suite(
  .dependencies {
    $0.defaultDatabase = TestSupport.testDatabase()
  },
  //  .snapshots(record: .failed)
)
@MainActor
struct SoundFontTests {

  @Test(
    .dependencies {
      $0.defaultDatabase = try appDatabase()
    }
  )
  func migration() async throws {
    @FetchAll(FontTag.all.order(by: \.id)) var tags
    try await $tags.load()

    @FetchAll(SoundFont.all.order(by: \.id)) var soundFonts
    try await $soundFonts.load()

    #expect(soundFonts.count == 4)
    #expect(soundFonts[0].displayName == SF2ResourceTag.fluidFont.name)
    #expect(soundFonts[0].id.rawValue == 1)

    #expect(soundFonts[1].displayName == SF2ResourceTag.freeFont.name)
    #expect(soundFonts[1].id.rawValue == 2)

    #expect(soundFonts[2].displayName == SF2ResourceTag.museScore.name)
    #expect(soundFonts[2].id.rawValue == 3)

    #expect(soundFonts[3].displayName == SF2ResourceTag.rolandNicePiano.name)
    #expect(soundFonts[3].id.rawValue == 4)

    #expect(!soundFonts[0].isInstalled)
    #expect(!soundFonts[1].isInstalled)
    #expect(!soundFonts[2].isInstalled)
    #expect(!soundFonts[3].isInstalled)

    #expect(!soundFonts[0].isExternal)
    #expect(!soundFonts[1].isExternal)
    #expect(!soundFonts[2].isExternal)
    #expect(!soundFonts[3].isExternal)

    #expect(soundFonts[0].isBuiltin)
    #expect(soundFonts[1].isBuiltin)
    #expect(soundFonts[2].isBuiltin)
    #expect(soundFonts[3].isBuiltin)

    #expect(try soundFonts[0].source().isBuiltin)
    #expect(try soundFonts[1].source().isBuiltin)
    #expect(try soundFonts[2].source().isBuiltin)
    #expect(try soundFonts[3].source().isBuiltin)

    #expect(soundFonts[0].sourceKind == "built-in")
    #expect(soundFonts[1].sourceKind == "built-in")
    #expect(soundFonts[2].sourceKind == "built-in")
    #expect(soundFonts[3].sourceKind == "built-in")

    #expect(!soundFonts[0].sourcePath.isEmpty && soundFonts[0].sourcePath != "N/A")
    #expect(!soundFonts[1].sourcePath.isEmpty && soundFonts[1].sourcePath != "N/A")
    #expect(!soundFonts[2].sourcePath.isEmpty && soundFonts[2].sourcePath != "N/A")
    #expect(!soundFonts[3].sourcePath.isEmpty && soundFonts[2].sourcePath != "N/A")

    #expect(soundFonts[1].embeddedName == "Free Font GM Ver. 3.2")
    #expect(soundFonts[1].embeddedComment == "")
    #expect(soundFonts[1].embeddedAuthor == "")
    #expect(soundFonts[1].embeddedCopyright == "")
    #expect(soundFonts[1].notes == "")

    #expect(soundFonts[0].tags.count == 2)
    #expect(soundFonts[1].tags.count == 2)
    #expect(soundFonts[2].tags.count == 2)
    #expect(soundFonts[3].tags.count == 2)

    #expect(soundFonts[0].presets.count == 189)
    #expect(soundFonts[1].presets.count == 235)
    #expect(soundFonts[2].presets.count == 270)
    #expect(soundFonts[3].presets.count == 1)

    #expect(soundFonts[0].allPresets.count == 189)
    #expect(soundFonts[1].allPresets.count == 235)
    #expect(soundFonts[2].allPresets.count == 270)
    #expect(soundFonts[3].allPresets.count == 1)

    #expect(soundFonts[0].elementCounts == (presetCount: 189, favoriteCount: 0, hiddenCount: 0))
    #expect(soundFonts[1].elementCounts == (presetCount: 235, favoriteCount: 0, hiddenCount: 0))
    #expect(soundFonts[2].elementCounts == (presetCount: 270, favoriteCount: 0, hiddenCount: 0))
    #expect(soundFonts[3].elementCounts == (presetCount: 1, favoriteCount: 0, hiddenCount: 0))
  }

  @Test
  func active() async throws {
    @FetchAll(SoundFont.all.order(by: \.id)) var soundFonts
    try await $soundFonts.load()
    #expect(soundFonts.count == 2)
    #expect(soundFonts.map(\.displayName) == [
      "Font 1",
      "Font 2"
    ])
  }

  @Test(
    .dependencies {
      $0.fileManager.fontFilePath = { FileManager.default.fontFilesDirectory.appendingPathComponent($0) }
    }
  )
  func add() async throws {
    @FetchAll(SoundFont.all.order(by: \.id)) var soundFonts
    try await $soundFonts.load()

    #expect(soundFonts.count == 2)

    SoundFont.delete(id: soundFonts[0].id)

    try await $soundFonts.load()
    #expect(soundFonts.count == 1)

    try FileManager.default.copyItem(at: SF2Resource.resources[3], to: FileManager.default.fontFilesDirectory.appendingPathComponent("Hubba.sf2"))
    let kind: SoundFontKind = .installed(filename: SF2Resource.resources[3].lastPathComponent)
    try SoundFont.add(displayName: "Hubba", soundFontKind: kind)

    try await $soundFonts.load()
    #expect(soundFonts.count == 2)
    #expect(soundFonts[1].displayName == "Hubba")
    #expect(soundFonts[1].sourceKind ==  "installed")

    let tags = soundFonts[1].tags
    #expect(tags.count == 2)
  }

  @Test
  func deletingSoundFontDeletesPresets() async throws {
    @FetchAll(SoundFont.all.order(by: \.id)) var soundFonts
    try await $soundFonts.load()
    #expect(soundFonts.count == 2)

    let sf = soundFonts[1]
    SoundFont.delete(id: sf.id)

    try await $soundFonts.load()
    #expect(soundFonts.count == 1)
    #expect(sf.allPresets.isEmpty)
  }

  @Test
  func deletingSoundFontUpdatesTags() async throws {
    let allTag = FontTag.with(id: FontTag.Ubiquitous.all.id)!
    let builtInTag = FontTag.with(id: FontTag.Ubiquitous.builtIn.id)!

    #expect(allTag.soundFonts.count == 2)
    #expect(builtInTag.soundFonts.count == 2)

    SoundFont.delete(id: 1)

    #expect(allTag.soundFonts.count == 1)
    #expect(builtInTag.soundFonts.count == 1)
  }
}
