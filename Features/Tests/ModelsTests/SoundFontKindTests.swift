import Dependencies
import Engine
import Foundation
import GRDB
import IdentifiedCollections
import SF2ResourceFiles
import Testing

@testable import Models

@Suite("SoundFontKind") struct SoundFontKindTests {
  @Test("creation") func creation() async throws {
    let builtin = SoundFontKind.builtin(resource: SF2ResourceFileTag.freeFont.url)
    #expect(builtin.isBuiltin)
    #expect(!builtin.isInstalled)
    #expect(!builtin.isExternal)
    let (kind, data) = try builtin.data()
    let back = try SoundFontKind(kind: kind, location: data)
    #expect(builtin == back)
    let fileInfo = try back.fileInfo()
    #expect(fileInfo.size() == 235)
  }
}
