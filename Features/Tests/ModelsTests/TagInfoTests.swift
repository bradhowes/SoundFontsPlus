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
  }
)
@MainActor
struct TagInfoTests {

  @Test
  func testQueryAll() async throws {
    let found = withDatabaseReader { try TagInfo.queryAll.fetchAll($0) } ?? []
    #expect(found.count == 5)
    #expect(found[0].soundFontsCount == 4)
    #expect(found[1].soundFontsCount == 2)
    #expect(found[2].soundFontsCount == 2)
    #expect(found[3].soundFontsCount == 1)
    #expect(found[4].soundFontsCount == 1)

    #expect(found[0].isUbiquitous == true)
    #expect(found[1].isUbiquitous == true)
    #expect(found[2].isUbiquitous == true)
    #expect(found[3].isUbiquitous == true)
    #expect(found[4].isUbiquitous == true)

    #expect(found[0].isUserDefined == false)
    #expect(found[1].isUserDefined == false)
    #expect(found[2].isUserDefined == false)
    #expect(found[3].isUserDefined == false)
    #expect(found[4].isUserDefined == false)
  }

  @Test
  func testQueryNonZero() async throws {
    let found = withDatabaseReader { try TagInfo.queryNonZero.fetchAll($0) } ?? []
    #expect(found.count == 5)
    #expect(found[0].soundFontsCount == 4)
    #expect(found[1].soundFontsCount == 2)
    #expect(found[2].soundFontsCount == 2)
    #expect(found[3].soundFontsCount == 1)
    #expect(found[4].soundFontsCount == 1)

    #expect(found[0].isUbiquitous == true)
    #expect(found[1].isUbiquitous == true)
    #expect(found[2].isUbiquitous == true)
    #expect(found[3].isUbiquitous == true)
    #expect(found[4].isUbiquitous == true)

    #expect(found[0].isUserDefined == false)
    #expect(found[1].isUserDefined == false)
    #expect(found[2].isUserDefined == false)
    #expect(found[3].isUserDefined == false)
    #expect(found[4].isUserDefined == false)
  }

  @Test(
    .dependencies {
      $0.defaultDatabase = try appDatabase()
    }
  )
  func liveQuery() async throws {
    let found = withDatabaseReader { try TagInfo.queryAll.fetchAll($0) } ?? []
    #expect(found.count == 5)
    #expect(found[0].soundFontsCount == 4)
    #expect(found[1].soundFontsCount == 4)
    #expect(found[2].soundFontsCount == 0)
    #expect(found[3].soundFontsCount == 0)
    #expect(found[4].soundFontsCount == 0)

    #expect(found[0].isUbiquitous == true)
    #expect(found[1].isUbiquitous == true)
    #expect(found[2].isUbiquitous == true)
    #expect(found[3].isUbiquitous == true)
    #expect(found[4].isUbiquitous == true)

    #expect(found[0].isUserDefined == false)
    #expect(found[1].isUserDefined == false)
    #expect(found[2].isUserDefined == false)
    #expect(found[3].isUserDefined == false)
    #expect(found[4].isUserDefined == false)
  }
}
