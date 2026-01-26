// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport
import Foundation
import Models
import SF2Resources
import SQLiteData
import SnapshotTesting
import SwiftUI
import Testing

public enum TestSupport {
  static let log: Logger = .init(category: "TestSupport")

  public static func testDatabase(seeder: ((Database) throws -> Void)? = addMockPresets) -> any DatabaseWriter {
    log.info("creating test database")
    // swiftlint:disable:next force_try
    return try! appDatabase(fonts: [], loadAllPresets: false, seeder: seeder)
  }
}

extension TestSupport {

  // swiftlint:disable:next function_body_length
  public static func addMockPresets(_ db: Database) throws {
    let fonts = [
      try SoundFontKind.builtin(tag: SF2ResourceTag.fluidFont).data(),
      try SoundFontKind.builtin(tag: SF2ResourceTag.freeFont).data(),
      try SoundFontKind.installed(filename: SF2ResourceTag.museScore.url.lastPathComponent).data(),
      try SoundFontKind.external(bookmark: Bookmark(url: SF2ResourceTag.rolandNicePiano.url, name: "Font4")).data()
    ]

    try SoundFont.insert {
      for (index, font) in fonts.enumerated() {
        SoundFont.Draft(
          displayName: "Font \(index + 1)",
          kind: font.0,
          location: font.1,
          originalName: "Original Font \(index + 1)",
          embeddedName: "Embedded Font \(index + 1)",
          embeddedComment: "",
          embeddedAuthor: "",
          embeddedCopyright: "",
          notes: ""
        )
      }
    }.execute(db)

    let kinds: [Preset.Kind] = [.preset, .preset, .hidden]

    for fontIndex in fonts.indices {
      try Preset.insert {
        for (presetIndex, kind) in kinds.enumerated() {
          Preset.Draft(
            index: presetIndex,
            bank: 0,
            program: presetIndex,
            originalName: "Original Preset \(presetIndex + 1)",
            soundFontId: .init(Int64(fontIndex + 1)),
            displayName: "Font \(fontIndex + 1) Preset \(presetIndex + 1)",
            notes: "",
            kind: kind
          )
        }
      }.execute(db)
    }

    try TaggedSoundFont.insert {
      for fontId in 1...4 {
        TaggedSoundFont(
          soundFontId: .init(Int64(fontId)),
          tagId: Tag.Ubiquitous.all.id
        )
      }
      for fontId in 1...2 {
        TaggedSoundFont(
          soundFontId: .init(Int64(fontId)),
          tagId: Tag.Ubiquitous.builtIn.id
        )
      }
      for fontId in 3...4 {
        TaggedSoundFont(
          soundFontId: .init(Int64(fontId)),
          tagId: Tag.Ubiquitous.added.id
        )
      }
      TaggedSoundFont(
        soundFontId: 3,
        tagId: Tag.Ubiquitous.device.id
      )
      TaggedSoundFont(
        soundFontId: 4,
        tagId: Tag.Ubiquitous.external.id
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
    installApplicationFont()
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
