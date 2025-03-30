import Testing

import ComposableArchitecture
import Dependencies
import GRDB
import Models
import SF2ResourceFiles
import SnapshotTesting
import SwiftUI
import Tagged
@testable import SoundFontsFeature

@MainActor
struct SupportTests {

  @Test func generateTagsList() async throws {
    try await TestSupport.initialize { _ in
      @Dependency(\.defaultDatabase) var database
      let tags = try database.read { try Models.Tag.fetchAll($0) }
      #expect(Support.generateTagsList(from: tags) == "Added, All, Built-in, External")
      #expect(Support.generateTagsList(from: [tags[0]]) == "All")
      #expect(Support.generateTagsList(from: [tags[0], tags[1]]) == "All, Built-in")
      #expect(Support.generateTagsList(from: []) == "")
    }
  }

  @Test func addSoundFonts() async throws {
    try await TestSupport.initialize { soundFonts in
      let result = Support.AddSoundFontsStatus(good: [soundFonts[0], soundFonts[1]], bad: [soundFonts[2].displayName])
      #expect(result.good.count == 2)
      #expect(result.bad.count == 1)
    }
  }
}
