// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
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
    prepareDependencies {
      $0.fileManager = .liveValue
    }

    let url = SF2ResourceTag.freeFont.url
    let bookmark = Bookmark(url: url, name: SF2ResourceTag.freeFont.name)
    #expect(bookmark.isUbiquitous == false)
  }

  @Test
  func testEncodingDecoding() throws {
    let url = SF2ResourceTag.freeFont.url
    let bookmark = Bookmark(url: url, name: SF2ResourceTag.freeFont.name)

    let data = try bookmark.toData()
    let bookmark2 = try Bookmark.from(data: data)

    #expect(bookmark == bookmark2)
  }

  @Test
  func cloudStateFor() {
    #expect(Bookmark.cloudState(for: nil) == .unknown)

    #expect(Bookmark.cloudState(for: .init(
      isUbiquitousItem: nil,
      ubiquitousItemDownloadingStatus: nil,
      ubiquitousItemIsDownloading: nil,
      ubiquitousItemDownloadingError: nil
    )) == .unknown)

    #expect(Bookmark.cloudState(for: .init(
      isUbiquitousItem: false,
      ubiquitousItemDownloadingStatus: nil,
      ubiquitousItemIsDownloading: nil,
      ubiquitousItemDownloadingError: nil
    )) == .local)

    #expect(Bookmark.cloudState(for: .init(
      isUbiquitousItem: true,
      ubiquitousItemDownloadingStatus: nil,
      ubiquitousItemIsDownloading: nil,
      ubiquitousItemDownloadingError: nil
    )) == .inCloud)

    #expect(Bookmark.cloudState(for: .init(
      isUbiquitousItem: true,
      ubiquitousItemDownloadingStatus: .downloaded,
      ubiquitousItemIsDownloading: true,
      ubiquitousItemDownloadingError: NSError(domain: "blah", code: -42)
    )) == .downloading)

    #expect(Bookmark.cloudState(for: .init(
      isUbiquitousItem: true,
      ubiquitousItemDownloadingStatus: .downloaded,
      ubiquitousItemIsDownloading: false,
      ubiquitousItemDownloadingError: NSError(domain: "blah", code: -42)
    )) == .downloadError)

    #expect(Bookmark.cloudState(for: .init(
      isUbiquitousItem: true,
      ubiquitousItemDownloadingStatus: .current,
      ubiquitousItemIsDownloading: nil,
      ubiquitousItemDownloadingError: nil
    )) == .downloaded)

    #expect(Bookmark.cloudState(for: .init(
      isUbiquitousItem: true,
      ubiquitousItemDownloadingStatus: .downloaded,
      ubiquitousItemIsDownloading: nil,
      ubiquitousItemDownloadingError: nil
    )) == .downloaded)

    #expect(Bookmark.cloudState(for: .init(
      isUbiquitousItem: true,
      ubiquitousItemDownloadingStatus: .notDownloaded,
      ubiquitousItemIsDownloading: nil,
      ubiquitousItemDownloadingError: nil
    )) == .inCloud)
 }

  @Test(
    .dependencies {
      $0.ubiquitousItemState = .constant(
        .init(
          isUbiquitousItem: true,
          ubiquitousItemDownloadingStatus: nil,
          ubiquitousItemIsDownloading: false,
          ubiquitousItemDownloadingError: nil
        )
      )
    }
  )
  func bookmarkCloudState() {
    let url = SF2ResourceTag.freeFont.url
    let bookmark = Bookmark(url: url, name: SF2ResourceTag.freeFont.name)
    #expect(bookmark.cloudState == .inCloud)
  }
}
