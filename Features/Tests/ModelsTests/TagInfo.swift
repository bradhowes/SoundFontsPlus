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
struct TagInfoTests {

  @Test func query() async throws {
    let found = withDatabaseReader { try TagInfo.query.fetchAll($0) } ?? []
    #expect(found.count == 4)
    #expect(found[0].soundFontsCount == 4)
    #expect(found[1].soundFontsCount == 4)
    #expect(found[2].soundFontsCount == 0)
    #expect(found[3].soundFontsCount == 0)

    #expect(found[0].isUbiquitous == true)
    #expect(found[1].isUbiquitous == true)
    #expect(found[2].isUbiquitous == true)
    #expect(found[3].isUbiquitous == true)

    #expect(found[0].isUserDefined == false)
    #expect(found[1].isUserDefined == false)
    #expect(found[2].isUserDefined == false)
    #expect(found[3].isUserDefined == false)
  }
}
