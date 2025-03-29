import Testing

import Dependencies
import GRDB
import SF2ResourceFiles
import Tagged
@testable import Models

struct BookmarkTests {

  @Test func testRestore() throws {
    let url = SF2ResourceFileTag.freeFont.url
    let bookmark = Bookmark(url: url, name: SF2ResourceFileTag.freeFont.name)
    #expect(bookmark.url == url)
  }

  @Test func testIsAvailable() throws {
    let url = SF2ResourceFileTag.freeFont.url
    let bookmark = Bookmark(url: url, name: SF2ResourceFileTag.freeFont.name)
    #expect(bookmark.isAvailable)
  }

  @Test func testCloudState() throws {
    prepareDependencies {
      $0.fileManager = .liveValue
    }

    let url = SF2ResourceFileTag.freeFont.url
    let bookmark = Bookmark(url: url, name: SF2ResourceFileTag.freeFont.name)
    #expect(bookmark.cloudState == .local)
  }

  @Test func testIsUbiquitous() throws {
    prepareDependencies {
      $0.fileManager = .liveValue
    }

    let url = SF2ResourceFileTag.freeFont.url
    let bookmark = Bookmark(url: url, name: SF2ResourceFileTag.freeFont.name)
    #expect(bookmark.isUbiquitous == false)
  }

  @Test func testEncodingDecoding() throws {
    let url = SF2ResourceFileTag.freeFont.url
    let bookmark = Bookmark(url: url, name: SF2ResourceFileTag.freeFont.name)

    let data = try bookmark.toData()
    let bookmark2 = try Bookmark.from(data: data)

    #expect(bookmark == bookmark2)
  }
}
