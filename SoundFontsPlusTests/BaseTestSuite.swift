import DependenciesTestSupport
import Foundation
import Numerics
import Sharing
import SnapshotTesting
import SQLiteData
import Testing
import SwiftUI

@testable import SoundFontsPlus

@Suite(
  .dependencies {
    $0.defaultDatabase = try SoundFontsPlus.appDatabase()
  },
  .snapshots(record: .failed)
)
struct BaseTestSuite {
  static var soundFontPresetLoadLimit: Int { SoundFont.soundFontPresetLoadLimit }
  static var isOnGithub: Bool { ProcessInfo.processInfo.isOnGithub }
  static var isLocal: Bool { !isOnGithub }
}

extension BaseTestSuite {

  static func fetchPreset(presetId: Preset.ID) async throws -> Preset {
    guard let preset = Preset.with(id: presetId) else {
      Issue.record("Failed to fetch existing preset")
      fatalError()
    }
    return preset
  }

  @inlinable
  static func makeUniqueSnapshotName(_ funcName: StaticString) -> String {
    "\(funcName)-iOS"
  }

  @MainActor
  static func assertSnap<V: SwiftUI.View>(
    matching: V,
    size: CGSize = CGSize(width: 400, height: 400),
    colorScheme: ColorScheme = .dark,
    background: Color = .black,
    fileID: StaticString = #fileID,
    file: StaticString = #filePath,
    testName: StaticString = #function,
    line: Int = #line,
    col: Int = #column
  ) throws {
    let uniqueTestName = makeUniqueSnapshotName(testName)

#if os(iOS)

    let view = __SnapshotTestViewWrapper(size: size, colorScheme: colorScheme, background: background) {
      matching
    }

    if let result = SnapshotTesting.verifySnapshot(
      of: view,
      as: .image(
        drawHierarchyInKeyWindow: false,
        layout: .fixed(width: size.width, height: size.height)
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
      print("uniqueTestName:", uniqueTestName)
      print("file:", file)
      if BaseTestSuite.isOnGithub {
        print("***", result)
      } else {
        Issue.record(
          Comment(rawValue: result),
          sourceLocation: .init(fileID: "\(fileID)", filePath: "\(file)", line: line, column: col)
        )
      }
    }
#endif // os(iOS)
  }
}

struct __SnapshotTestViewWrapper<Content: View>: View {
  let size: CGSize
  let content: Content
  let colorScheme: ColorScheme
  let background: Color

  public init(size: CGSize, colorScheme: ColorScheme, background: Color?,  @ViewBuilder _ content: () -> Content) {
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
