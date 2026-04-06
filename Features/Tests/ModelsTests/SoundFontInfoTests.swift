// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
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

  @Shared(.hideBuiltinFonts) var hideBuiltinFonts = false
  @Shared(.hideEmptyTags) var hideEmptyTags = false

  init() {
    $hideBuiltinFonts.withLock { $0 = false }
    $hideEmptyTags.withLock { $0 = false }
  }

  @Test
  func query() async throws {
    var found = withDatabaseReader { try SoundFontInfo.query(for: 99).fetchAll($0) } ?? []
    #expect(found.isEmpty)

    found = withDatabaseReader { try SoundFontInfo.query(for: Tag.Ubiquitous.all.id).fetchAll($0) } ?? []
    guard !found.isEmpty else {
      Issue.record("found is empty")
      return
    }

    #expect(found.count == 4)
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
