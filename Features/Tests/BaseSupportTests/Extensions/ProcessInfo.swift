import Foundation
import Testing

@testable import BaseSupport

@Suite(
  //  .dependencies {
  //    $0.defaultDatabase = try appDatabase()
  //  },
  //  .snapshots(record: .failed)
)
struct ProcessInfoTests {

  @Test func isOnGithub() {
    #expect(ProcessInfo.processInfo.isOnGithub == ProcessInfo.processInfo.isOnGithub)
  }
}
