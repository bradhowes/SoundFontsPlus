// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
import SF2Resources
import Testing

@testable import Models

struct BookmarkTests {

  @Test func testRestore() throws {
    let url = SF2ResourceTag.freeFont.url
    let bookmark = Bookmark(url: url, name: SF2ResourceTag.freeFont.name)
    #expect(bookmark.url == url)
  }

  @Test func testIsAvailable() throws {
    let url = SF2ResourceTag.freeFont.url
    let bookmark = Bookmark(url: url, name: SF2ResourceTag.freeFont.name)
    #expect(bookmark.isAvailable)
  }

  @Test func testCloudState() throws {
    prepareDependencies {
      $0.fileManager = .liveValue
    }

    let url = SF2ResourceTag.freeFont.url
    let bookmark = Bookmark(url: url, name: SF2ResourceTag.freeFont.name)
    #expect(bookmark.cloudState == .local)
  }

  @Test func testIsUbiquitous() throws {
    prepareDependencies {
      $0.fileManager = .liveValue
    }

    let url = SF2ResourceTag.freeFont.url
    let bookmark = Bookmark(url: url, name: SF2ResourceTag.freeFont.name)
    #expect(bookmark.isUbiquitous == false)
  }

  @Test func testEncodingDecoding() throws {
    let url = SF2ResourceTag.freeFont.url
    let bookmark = Bookmark(url: url, name: SF2ResourceTag.freeFont.name)

    let data = try bookmark.toData()
    let bookmark2 = try Bookmark.from(data: data)

    #expect(bookmark == bookmark2)
  }
}
