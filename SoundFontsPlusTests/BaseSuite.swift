import DependenciesTestSupport
import Foundation
import Sharing
import Testing

@testable import SoundFontsPlus

@Suite(.dependencies) struct BaseSuite {
  static let isOnGithub = ProcessInfo.processInfo.environment["XCTestBundlePath"]?.contains("/Users/runner/work") ?? false
}
