// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
import Foundation
import Sharing
import SQLiteData
import Testing

@testable import Models

@Suite(
  .dependencies {
    $0.defaultDatabase = try appDatabase()
  },
  //  .snapshots(record: .failed)
)
@MainActor
struct SoundFontInfoTests {

  @Test func query() async throws {
    @Shared(.activeState) var activeState
    $activeState.withLock { $0.activeTagId = 99 }
    var found = withDatabaseReader { try SoundFontInfo.query().fetchAll($0) } ?? []
    #expect(found.count == 0)

    $activeState.withLock { $0.activeTagId = nil }
    found = withDatabaseReader { try SoundFontInfo.query().fetchAll($0) } ?? []
    #expect(found.count == 4)

    $activeState.withLock { $0.activeTagId = FontTag.Ubiquitous.all.id }
    found = withDatabaseReader { try SoundFontInfo.query().fetchAll($0) } ?? []
    #expect(found.count == 4)
    #expect(found[0].id == 1)
    #expect(found[1].id == 2)
    #expect(found[2].id == 3)
    #expect(found[3].id == 4)

    #expect(found[0].displayName == "Fluid R3")
    #expect(found[1].displayName == "FreeFont")
    #expect(found[2].displayName == "MuseScore")
    #expect(found[3].displayName == "Roland Piano")

    #expect(found[0].isInstalled == false)
    #expect(found[1].isInstalled == false)
    #expect(found[2].isInstalled == false)
    #expect(found[3].isInstalled == false)

    #expect(found[0].isExternal == false)
    #expect(found[1].isExternal == false)
    #expect(found[2].isExternal == false)
    #expect(found[3].isExternal == false)

    #expect(found[0].isBuiltin == true)
    #expect(found[1].isBuiltin == true)
    #expect(found[2].isBuiltin == true)
    #expect(found[3].isBuiltin == true)
  }
}
