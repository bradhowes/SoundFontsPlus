import Foundation
import Testing

@testable import BaseSupport

@Suite(
  //  .dependencies {
  //    $0.defaultDatabase = try appDatabase()
  //  },
  //  .snapshots(record: .failed)
)
struct BundleTests {

  @Test func stringForKey() async throws {
    let bundle = Bundle.main
    #expect(bundle.string(forKey: "BlahBlahBlah") == "")
    #expect(bundle.string(forKey: "CFBundleShortVersionString") != "")
  }

  @Test func releaseVersionNumber() async throws {
    let bundle = Bundle.main
    #expect(bundle.releaseVersionNumber != "")
    #expect(Double(bundle.releaseVersionNumber) != nil)
  }

  @Test func buildVersionNumber() async throws {
    let bundle = Bundle.main
    #expect(bundle.buildVersionNumber != "")
    #expect(Int(bundle.buildVersionNumber) != nil)
  }

  @Test func versionString() async throws {
    let bundle = Bundle.main
    #expect(bundle.versionString != "")
  }

  @Test func changeLogFile() async throws {
    let bundle = Bundle.main
    #expect(bundle.changeLogFile == nil)
  }

  @Test func changeLog() async throws {
    let bundle = Bundle.main
    #expect(bundle.changeLog == "")
  }
}

