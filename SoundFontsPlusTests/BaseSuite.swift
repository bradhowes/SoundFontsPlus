import DependenciesTestSupport
import Foundation
import Sharing
import SnapshotTesting
import Testing
import SwiftUI

// @testable import SoundFontsPlus

@Suite(.dependencies) struct BaseSuite {}

public struct __SnapshotTestViewWrapper<Content: View>: View {
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

@inlinable
func makeUniqueSnapshotName(_ funcName: StaticString) -> String {
  "\(funcName)-iOS"
}

@MainActor @inlinable
func assertSnapshot<V: SwiftUI.View>(
  matching: V,
  size: CGSize = CGSize(width: 400, height: 400),
  colorScheme: ColorScheme = .light,
  background: Color? = nil,
  fileID: StaticString = #fileID,
  file: StaticString = #filePath,
  testName: StaticString = #function,
  line: Int = #line,
  col: Int = #column
) throws {
  print("*** assertSnapshot")
#if os(iOS)
  let uniqueTestName = makeUniqueSnapshotName(testName)
  print("*** assertSnapshot - \(uniqueTestName)")
  let isOnGithub = (ProcessInfo.processInfo.environment["GITHUB_STEP_SUMMARY"] ?? "").count > 0
  print("*** GITHUB_STEP_SUMMARY: \(ProcessInfo.processInfo.environment["GITHUB_STEP_SUMMARY"] ?? "")")

  print("*** assertSnapshot - iOS")

  print("*** assertSnapshot - before view")
//  let view = __SnapshotTestViewWrapper(size: size, colorScheme: colorScheme, background: background) {
//    matching
//  }

  print("*** assertSnapshot - before verifySnapshot")

//  if let result = SnapshotTesting.verifySnapshot(
//    of: view,
//    as: .image(
//      drawHierarchyInKeyWindow: false,
//      layout: .fixed(width: size.width, height: size.height)
//    ),
//    named: uniqueTestName,
//    file: file,
//    testName: "\(testName)",
//    line: UInt(line)
//  ) {
//    print("*** result: \(result)")
//    print("uniqueTestName:", uniqueTestName)
//    print("file:", file)
//    if isOnGithub {
//      print("***", result)
//    } else {
//      Issue.record(Comment(rawValue: result), sourceLocation: .init(fileID: "\(fileID)", filePath: "\(file)", line: line, column: col))
//    }
//  }
#endif
}

