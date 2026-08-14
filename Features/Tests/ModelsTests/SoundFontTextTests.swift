// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import Foundation
import Sharing
import SQLiteData
import Tagged
import Testing
import TestSupport

@testable import Models

@Suite(
  .dependencies {
    $0.defaultDatabase = TestSupport.testDatabase()
  }
)
@MainActor
struct SoundFontTextTests {

  @Shared(.hideBuiltinFonts) var hideBuiltinFonts = false
  @Shared(.hideEmptyTags) var hideEmptyTags = false

  init() {
    $hideBuiltinFonts.withLock { $0 = false }
    $hideEmptyTags.withLock { $0 = false }
  }

  @Test
  func textQueryOnName() async throws {
    let found = withDatabaseReader {
      try SoundFontInfo
        .query(for: Tag.Ubiquitous.all.id, search: "Font")
        .fetchAll($0)
    } ?? []
    #expect(found.count == 4)
  }

  @Test
  func textQueryOnMetaFields() async throws {
    for (index, term) in ["Original", "Embedded", "Comment", "Author", "Copyright", "Notes"].enumerated() {
      let found = withDatabaseReader {
        try SoundFontInfo
          .query(for: Tag.Ubiquitous.all.id, search: term)
          .fetchAll($0)
      } ?? []
      #expect(found.count == (index < 4 ? 1 : 2))
      if index < 4 {
        #expect(found[0].id == SoundFont.ID(rawValue: Int64(index % 4) + 1))
      } else {
        #expect(found[0].id == SoundFont.ID(rawValue: Int64(index % 4) + 1) ||
                found[1].id == SoundFont.ID(rawValue: Int64(index % 4) + 1))
      }
    }
  }

  @Test
  func textQueryOR() async throws {
    let found = withDatabaseReader {
      try SoundFontInfo
        .query(for: Tag.Ubiquitous.all.id, search: "Ori OR Emb")
        .fetchAll($0)
    } ?? []
    #expect(found.count == 2)
  }

  @Test
  func textQueryAND() async throws {
    let found = withDatabaseReader {
      try SoundFontInfo
        .query(for: Tag.Ubiquitous.all.id, search: "Ori AND Font")
        .fetchAll($0)
    } ?? []
    #expect(found.count == 1)
  }
}
