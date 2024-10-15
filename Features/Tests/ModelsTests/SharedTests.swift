import XCTest
import ComposableArchitecture
import Foundation

@testable import Models

final class SharedTests: XCTestCase {
  typealias ActiveSchema = SchemaV1

  func testSelectedSoundFont() throws {
    try withNewContext(ActiveSchema.self) { context in
      try withTestAppStorage {
        @Shared(.selectedSoundFontKey) var foo
        XCTAssertNil(foo)

        let fonts = try! context.fetch(SoundFontModel.fetchDescriptor())
        foo = fonts[0].key

        @Shared(.selectedSoundFontKey) var bar
        XCTAssertEqual(bar, fonts[0].key)

        bar = nil
        XCTAssertNil(foo)
      }
    }
  }

  func testActiveSoundFont() throws {
    try withNewContext(ActiveSchema.self) { context in
      try withTestAppStorage {
        @Shared(.activeSoundFontKey) var foo
        XCTAssertNil(foo)

        let fonts = try! context.fetch(SoundFontModel.fetchDescriptor())
        foo = fonts[0].key

        @Shared(.activeSoundFontKey) var bar
        XCTAssertEqual(bar, fonts[0].key)

        bar = nil
        XCTAssertNil(foo)
      }
    }
  }

  func testActivePreset() throws {
    try withNewContext(ActiveSchema.self) { context in
      try withTestAppStorage {
        @Shared(.activePresetKey) var foo
        XCTAssertEqual(foo, -1)

        foo = 123

        @Shared(.activePresetKey) var bar
        XCTAssertEqual(bar, 123)

        bar = -1
        XCTAssertEqual(foo, -1)
      }
    }
  }

  func testActiveTag() throws {
    try withNewContext(ActiveSchema.self) { context in
      try withTestAppStorage {
        @Shared(.activeTagKey) var foo
        XCTAssertEqual(foo, TagModel.Ubiquitous.all.key)

        foo = TagModel.Ubiquitous.external.key

        @Shared(.activeTagKey) var bar
        XCTAssertEqual(bar, TagModel.Ubiquitous.external.key)
      }
    }
  }
}

