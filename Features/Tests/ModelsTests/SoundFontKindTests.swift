// Copyright © 2025 Brad Howes. All rights reserved.

import BaseSupport
import Foundation
import SF2Resources
import Testing

@testable import Models

@Suite(
  .dependencies {
    $0.fileManager.fontFilePath = {
      SF2ResourceTag.freeFont.url.deletingLastPathComponent().appendingPathComponent($0, isDirectory: false)
    }
  }
)
@MainActor
struct SoundFontKindTests {

  @Test
  func builtin() async throws {
    let sfk = SoundFontKind.builtin(tag: SF2ResourceTag.freeFont)
    #expect(sfk.isBuiltin)
    #expect(!sfk.isInstalled)
    #expect(!sfk.isExternal)
    let (kind, data) = try sfk.data()
    #expect(sfk.description == "built-in")
    #expect(sfk.url == SF2ResourceTag.freeFont.url)
    let back = try SoundFontKind(kind: kind, location: data, displayName: "blah")
    #expect(sfk == back)

    let fileInfo = try back.fileInfo()
    #expect(fileInfo.size() == 235)

    #expect(sfk.tagIds == [-1, -2]) // all, builtIn
    #expect(sfk.addedByUser == false)
    #expect(sfk.deleteWhenRemoved == false)
  }

  @Test
  func installed() async throws {
    let sfk = SoundFontKind.installed(filename: SF2ResourceTag.freeFont.url.lastPathComponent)
    #expect(!sfk.isBuiltin)
    #expect(sfk.isInstalled)
    #expect(!sfk.isExternal)
    #expect(sfk.description == "installed")
    #expect(try sfk.data() == (.installed, Data(SF2ResourceTag.freeFont.url.lastPathComponent.utf8)))
    #expect(sfk.url == SF2ResourceTag.freeFont.url)

    let fileInfo = try sfk.fileInfo()
    #expect(fileInfo.size() == 235)

    #expect(sfk.tagIds == [-1, -3, -4]) // all, added, device
    #expect(sfk.addedByUser == true)
    #expect(sfk.deleteWhenRemoved == true)
  }

  @Test
  func external() async throws {
    let url = SF2ResourceTag.freeFont.url
    let bookmark = Bookmark(url: url, name: SF2ResourceTag.freeFont.name)
    let data = try bookmark.toData()
    let sfk = try SoundFontKind(kind: .external, location: data, displayName: "blah")
    #expect(!sfk.isBuiltin)
    #expect(!sfk.isInstalled)
    #expect(sfk.isExternal)
    #expect(sfk.description == "external link")
    #expect(try sfk.data() == (.external, data))
    #expect(sfk.url == SF2ResourceTag.freeFont.url)

    let fileInfo = try sfk.fileInfo()
    #expect(fileInfo.size() == 235)

    #expect(sfk.tagIds == [-1, -3, -5]) // all, added, external
    #expect(sfk.addedByUser == true)
    #expect(sfk.deleteWhenRemoved == false)
  }

  @Test
  func dataToUrl() throws {
    let data = Data(count: 0)
    #expect(throws: ModelError.dataIsNotValidTag(data: data, displayName: "blah")) {
      try SoundFontKind(kind: .builtin, location: data, displayName: "blah")
    }
  }
}
