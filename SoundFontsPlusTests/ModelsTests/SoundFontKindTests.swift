import Foundation
import Testing

@testable import SoundFontsPlus

@Suite("SoundFontKind") struct SoundFontKindTests {
  
  @Test func builtin() async throws {
    let sfk = SoundFontKind.builtin(resource: SF2ResourceFileTag.freeFont.url)
    #expect(sfk.isBuiltin)
    #expect(!sfk.isInstalled)
    #expect(!sfk.isExternal)
    let (kind, data) = try sfk.data()
    #expect(sfk.description == "built-in")
    #expect(sfk.path == SF2ResourceFileTag.freeFont.url)
    let back = try SoundFontKind(kind: kind, location: data)
    #expect(sfk == back)

    let fileInfo = try back.fileInfo()
    #expect(fileInfo.size() == 235)

    #expect(sfk.tagIds == [1, 2]) // all, builtIn
    #expect(sfk.addedByUser == false)
    #expect(sfk.deleteWhenRemoved == false)
  }

  @Test func installed() async throws {
    let builtin = SoundFontKind.builtin(resource: SF2ResourceFileTag.freeFont.url)
    let (_, data) = try builtin.data()
    let sfk = try SoundFontKind(kind: .installed, location: data)
    #expect(!sfk.isBuiltin)
    #expect(sfk.isInstalled)
    #expect(!sfk.isExternal)
    #expect(sfk.description == "installed")
    #expect(try sfk.data() == (.installed, SF2ResourceFileTag.freeFont.url.absoluteString.data(using: .utf8)))
    #expect(try sfk.path == SF2ResourceFileTag.freeFont.url)

    let fileInfo = try sfk.fileInfo()
    #expect(fileInfo.size() == 235)

    #expect(sfk.tagIds == [1, 3]) // all, added
    #expect(sfk.addedByUser == true)
    #expect(sfk.deleteWhenRemoved == true)
  }

  @Test func external() async throws {
    let url = SF2ResourceFileTag.freeFont.url
    let bookmark = Bookmark(url: url, name: SF2ResourceFileTag.freeFont.name)
    let data = try bookmark.toData()
    let sfk = try SoundFontKind(kind: .external, location: data)
    #expect(!sfk.isBuiltin)
    #expect(!sfk.isInstalled)
    #expect(sfk.isExternal)
    #expect(sfk.description == "external link")
    #expect(try sfk.data() == (.external, data))
    #expect(try sfk.path == SF2ResourceFileTag.freeFont.url)

    let fileInfo = try sfk.fileInfo()
    #expect(fileInfo.size() == 235)

    #expect(sfk.tagIds == [1, 3, 4]) // all, added, external
    #expect(sfk.addedByUser == true)
    #expect(sfk.deleteWhenRemoved == false)
  }

  @Test func fileInfo() throws {
    let url = SF2ResourceFileTag.freeFont.url.appendingPathComponent(".bogus")
    let sfk = SoundFontKind.builtin(resource: url)
    #expect(throws: ModelError.loadFailure(name: url.absoluteString)) {
      try sfk.fileInfo()
    }
  }

  @Test func dataToUrl() throws {
    let data = Data(count: 0)
    #expect(throws: ModelError.dataIsNotValidURL(data: data)) {
      try SoundFontKind(kind: .builtin, location: data)
    }
  }
}
