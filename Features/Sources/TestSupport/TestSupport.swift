// Copyright © 2025 Brad Howes. All rights reserved.

import BaseSupport
import Foundation
import Models
import SF2Resources
import SQLiteData
import SnapshotTesting
import SwiftUI
import Testing

public enum TestSupport {
  static let log = Logger(category: "TestSupport")

  public static func testDatabase(seeder: ((Database) throws -> Void)? = addMockPresets) -> any DatabaseWriter {
    // swiftlint:disable:next force_try
    try! appDatabase(fonts: [], loadAllPresets: false, seeder: seeder)
  }
}

extension TestSupport {
  // swiftlint:disable:next function_body_length
  public static func addMockPresets(_ db: Database) throws {
    let font1 = try SoundFontKind.builtin(resource: SF2ResourceTag.fluidFont.url).data()
    let font2 = try SoundFontKind.builtin(resource: SF2ResourceTag.freeFont.url).data()

    try SoundFont.insert {
      SoundFont.Draft(
        displayName: "Font 1",
        kind: font1.0,
        location: font1.1,
        originalName: "Original Font 1",
        embeddedName: "Embedded Font 1",
        embeddedComment: "",
        embeddedAuthor: "",
        embeddedCopyright: "",
        notes: "",
      )
      SoundFont.Draft(
        displayName: "Font 2",
        kind: font2.0,
        location: font2.1,
        originalName: "Original Font 1",
        embeddedName: "Embedded Font 1",
        embeddedComment: "",
        embeddedAuthor: "",
        embeddedCopyright: "",
        notes: "",
      )
    }.execute(db)
    try Preset.insert {
      Preset.Draft(
        index: 0,
        bank: 0,
        program: 0,
        originalName: "Original Preset 1",
        soundFontId: 1,
        displayName: "Font 1 Preset 1",
        notes: "",
        kind: .preset
      )
      Preset.Draft(
        index: 1,
        bank: 0,
        program: 1,
        originalName: "Original Preset 2",
        soundFontId: 1,
        displayName: "Font 1 Preset 2",
        notes: "",
        kind: .preset
      )
      Preset.Draft(
        index: 0,
        bank: 0,
        program: 0,
        originalName: "Original Preset 1",
        soundFontId: 2,
        displayName: "Font 2 Preset 1",
        notes: "",
        kind: .preset
      )
      Preset.Draft(
        index: 1,
        bank: 0,
        program: 1,
        originalName: "Original Preset 2",
        soundFontId: 2,
        displayName: "Font 2 Preset 2",
        notes: "",
        kind: .preset
      )
    }.execute(db)
    try TaggedSoundFont.insert {
      TaggedSoundFont(
        soundFontId: 1,
        tagId: 1
      )
      TaggedSoundFont(
        soundFontId: 2,
        tagId: 1
      )
      TaggedSoundFont(
        soundFontId: 1,
        tagId: 2
      )
      TaggedSoundFont(
        soundFontId: 2,
        tagId: 2
      )
    }.execute(db)
  }
}

extension TestSupport {

  public enum SnapshotConfig {
    case portrait
    case landscape
    case tablet
  }

  @MainActor
  public static func assertSnapshot<V: SwiftUI.View>(
    matching: V,
    size: CGSize? = nil,
    config: SnapshotConfig = .portrait,
    colorScheme: ColorScheme = .dark,
    background: Color = .black,
    fileID: StaticString = #fileID,
    file: StaticString = #filePath,
    testName: StaticString = #function,
    line: Int = #line,
    col: Int = #column
  ) throws {
    let uniqueTestName = makeUniqueSnapshotName(testName)
    log.info("assertSnapshot - \(uniqueTestName)")
    //    for (key, value) in ProcessInfo.processInfo.environment {
    //      log.info("environment[\(key)]: \(value)")
    //    }

    let width = size?.width ?? config.size.width
    let height = size?.height ?? config.size.height
    let layout: SwiftUISnapshotLayout = .fixed(width: width, height: height)

    let view = SnapshotTestViewWrapper(
      size: .init(width: width, height: height),
      colorScheme: colorScheme,
      background: background
    ) {
      matching
    }

    if let result = SnapshotTesting.verifySnapshot(
      of: view,
      as: .image(
        drawHierarchyInKeyWindow: false,
        layout: layout,
        traits: config.traits
      ),
      named: uniqueTestName,
      record: nil,
      snapshotDirectory: nil,
      timeout: 5,
      fileID: fileID,
      file: file,
      testName: "\(testName)",
      line: UInt(line),
      column: UInt(col)
    ) {
      // Only record failures when not runnng in CI pipeline on Github
      if ProcessInfo.processInfo.isOnGithub {
        log.info("*** \(result)")
      } else {
        Issue.record(
          Comment(rawValue: result),
          sourceLocation: .init(fileID: "\(fileID)", filePath: "\(file)", line: line, column: col)
        )
      }
    }
  }
}

extension TestSupport {

  @inlinable
  static func makeUniqueSnapshotName(_ funcName: StaticString) -> String {
#if os(iOS)
    "\(funcName)-iOS"
#endif // os(iOS)
#if os(macOS)
    "\(funcName)-macOS"
#endif // os(macOS)
  }

  private struct SnapshotTestViewWrapper<Content: View>: View {
    let size: CGSize
    let content: Content
    let colorScheme: ColorScheme
    let background: Color

    public init(size: CGSize, colorScheme: ColorScheme, background: Color?, @ViewBuilder _ content: () -> Content) {
      self.size = size
      self.content = content()
      self.colorScheme = colorScheme
      self.background = background ?? (colorScheme == .dark ? .black : .white)
    }

    public var body: some View {
      Group {
        content
      }
      .frame(width: size.width, height: size.height)
      .background(background)
      .environment(\.colorScheme, colorScheme)
    }
  }
}

extension TestSupport.SnapshotConfig {

  public var size: CGSize {
    switch self {
    case .landscape: return .init(width: 800, height: 400)
    case .portrait: return .init(width: 400, height: 800)
    case .tablet: return .init(width: 800, height: 800)
    }
  }

  private func sharedTraits(_ mutations: inout UIMutableTraits) {
    mutations.layoutDirection = .leftToRight
    mutations.preferredContentSizeCategory = .medium
    mutations.userInterfaceIdiom = .phone
  }

  public var traits: UITraitCollection {
    switch self {
    case .landscape: return .init(
      mutations: {
        sharedTraits(&$0)
        $0.horizontalSizeClass = .regular
        $0.verticalSizeClass = .compact
      }
    )

    case .portrait: return .init(
      mutations: {
        sharedTraits(&$0)
        $0.horizontalSizeClass = .compact
        $0.verticalSizeClass = .regular
      }
    )

    case .tablet: return .init(
      mutations: {
        sharedTraits(&$0)
        $0.horizontalSizeClass = .regular
        $0.verticalSizeClass = .regular
      }
    )
    }
  }
}
