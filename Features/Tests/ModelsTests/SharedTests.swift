import XCTest
import ComposableArchitecture
import Dependencies
import Foundation

@testable import Models

final class SharedTests: XCTestCase {
  typealias ActiveSchema = SchemaV1

  func testSelectedSoundFont() throws {
    try withNewContext(ActiveSchema.self) { context in
      try withTestAppStorage {
        @Shared(.selectedSoundFont) var foo
        XCTAssertNil(foo)

        let fonts = try! context.fetch(SoundFontModel.fetchDescriptor())
        foo = fonts[0].soundFontId

        @Shared(.selectedSoundFont) var bar
        XCTAssertEqual(bar, fonts[0].soundFontId)

        bar = nil
        XCTAssertNil(foo)
      }
    }
  }

  func testActiveSoundFont() throws {
    try withNewContext(ActiveSchema.self) { context in
      try withTestAppStorage {
        @Shared(.activeSoundFont) var foo
        XCTAssertNil(foo)

        let fonts = try! context.fetch(SoundFontModel.fetchDescriptor())
        foo = fonts[0].soundFontId

        @Shared(.activeSoundFont) var bar
        XCTAssertEqual(bar, fonts[0].soundFontId)

        bar = nil
        XCTAssertNil(foo)
      }
    }
  }

  func testActivePreset() throws {
    try withNewContext(ActiveSchema.self) { context in
      try withTestAppStorage {
        @Shared(.activePreset) var foo
        XCTAssertEqual(foo, 0)

        foo = 123

        @Shared(.activePreset) var bar
        XCTAssertEqual(bar, 123)

        bar = -1
        XCTAssertEqual(foo, -1)
      }
    }
  }

  func testActiveTag() throws {
    try withNewContext(ActiveSchema.self) { context in
      try withTestAppStorage {
        @Shared(.activeTag) var foo
        XCTAssertNil(foo)

        foo = try TagModel.ubiquitous(.all).uuid

        @Shared(.activeTag) var bar
        XCTAssertEqual(bar, foo)

        bar = nil
        XCTAssertNil(foo)
      }
    }
  }
}

