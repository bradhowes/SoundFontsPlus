import XCTest
import ComposableArchitecture
import Foundation

@testable import Models

final class SharedTests: XCTestCase {
  typealias ActiveSchema = SchemaV1

  func testSelectedSoundFont() throws {
    try withNewContext(ActiveSchema.self) { context in
      try withTestAppStorage {
        @Shared(.activeState) var foo
        XCTAssertNil(foo.selectedSoundFontKey)

        let fonts = try! context.fetch(SoundFontModel.fetchDescriptor())
        foo.setSelectedSoundFontKey(fonts[0].key)

        @Shared(.activeState) var bar
        XCTAssertEqual(bar.selectedSoundFontKey, fonts[0].key)

        bar.setSelectedSoundFontKey(nil)
        XCTAssertNil(foo.selectedSoundFontKey)
      }
    }
  }

  func testActiveSoundFont() throws {
    try withNewContext(ActiveSchema.self) { context in
      try withTestAppStorage {
        @Shared(.activeState) var foo
        XCTAssertNil(foo.activeSoundFontKey)

        let fonts = try! context.fetch(SoundFontModel.fetchDescriptor())
        foo.setActiveSoundFontKey(fonts[0].key)

        @Shared(.activeState) var bar
        XCTAssertEqual(bar.activeSoundFontKey, fonts[0].key)

        bar.setActiveSoundFontKey(nil)
        XCTAssertNil(foo.activeSoundFontKey)
      }
    }
  }

  func testActivePreset() throws {
    try withNewContext(ActiveSchema.self) { context in
      try withTestAppStorage {
        @Shared(.activeState) var foo
        XCTAssertNil(foo.activePresetKey)

        foo.setActivePresetKey(.init(20))

        @Shared(.activeState) var bar
        XCTAssertEqual(bar.activePresetKey, .init(20))

        bar.setActivePresetKey(nil)
        XCTAssertNil(foo.activePresetKey)
      }
    }
  }

  func testActiveTag() throws {
    try withNewContext(ActiveSchema.self) { context in
      try withTestAppStorage {
        @Shared(.activeState) var foo
        XCTAssertNil(foo.activeTagKey)

        foo.setActiveTagKey(TagModel.Ubiquitous.external.key)

        @Shared(.activeState) var bar
        XCTAssertEqual(bar.activeTagKey, TagModel.Ubiquitous.external.key)
      }
    }
  }
}

