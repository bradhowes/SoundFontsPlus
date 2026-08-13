// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
import DependenciesTestSupport
import Foundation
import SF2Resources
import Testing

@testable import BaseSupport

struct BookmarkTests {

  @Test
  func testRestore() throws {
    let url = SF2ResourceTag.freeFont.url
    let bookmark = Bookmark(url: url, name: SF2ResourceTag.freeFont.name)
    #expect(bookmark.url == url)
  }

  @Test
  func testIsAvailable() throws {
    let url = SF2ResourceTag.freeFont.url
    let bookmark = Bookmark(url: url, name: SF2ResourceTag.freeFont.name)
    #expect(bookmark.isAvailable)
  }

  @Test
  func testIsUbiquitous() throws {
    withDependencies {
      $0.fileManager = .liveValue
    } operation: {
      let url = SF2ResourceTag.freeFont.url
      let bookmark = Bookmark(url: url, name: SF2ResourceTag.freeFont.name)
      #expect(bookmark.isUbiquitous == false)
    }
  }

  @Test
  func testEncodingDecoding() throws {
    let url = SF2ResourceTag.freeFont.url
    let bookmark = Bookmark(url: url, name: SF2ResourceTag.freeFont.name)

    let data = try bookmark.toData()
    let bookmark2 = try Bookmark.from(data: data)

    #expect(bookmark == bookmark2)
  }

  @Test(
    .dependencies {
      $0.urlStateProvider = .constant(
        .init(
          fileExists: true,
          isUbiquitousItem: true,
          ubiquitousItemDownloadingStatus: nil,
          ubiquitousItemIsDownloading: false,
          ubiquitousItemDownloadingError: nil
        )
      )
    }
  )
  func bookmarkCloudState() {
//    let url = SF2ResourceTag.freeFont.url
//    let bookmark = Bookmark(url: url, name: SF2ResourceTag.freeFont.name)
    // #expect(bookmark.cloudState == .inCloud)
  }
}
