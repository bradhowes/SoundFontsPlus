// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
import Foundation
import Sharing
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
struct SoundFontInfoTests {

  @Test
  func query() async throws {
    @Shared(.activeState) var activeState
    $activeState.withLock { $0.activeTagId = 99 }
    var found = withDatabaseReader { try SoundFontInfo.query().fetchAll($0) } ?? []
    #expect(found.isEmpty)

    $activeState.withLock { $0.activeTagId = nil }
    found = withDatabaseReader { try SoundFontInfo.query().fetchAll($0) } ?? []
    #expect(found.count == 2)

    $activeState.withLock { $0.activeTagId = FontTag.Ubiquitous.all.id }
    found = withDatabaseReader { try SoundFontInfo.query().fetchAll($0) } ?? []
    #expect(found.count == 2)
    #expect(found[0].id == 1)
    #expect(found[1].id == 2)

    #expect(found[0].displayName == "Font 1")
    #expect(found[1].displayName == "Font 2")

    #expect(found[0].isInstalled == false)
    #expect(found[1].isInstalled == false)

    #expect(found[0].isExternal == false)
    #expect(found[1].isExternal == false)

    #expect(found[0].isBuiltin == true)
    #expect(found[1].isBuiltin == true)
  }
}
