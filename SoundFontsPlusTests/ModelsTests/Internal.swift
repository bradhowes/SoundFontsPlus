import Foundation
import SharingGRDB
import Testing

@testable import SoundFontsPlus

@Suite(
  .dependencies {
    $0.defaultDatabase = try SoundFontsPlus.appDatabase()
    try $0.defaultDatabase.write { try $0.seedTestData() }
  },
  .snapshots(record: .failed)
)
struct BaseTestSuite {}

extension Database {

  func seedTestData() throws {
//    try seed {
//    }
  }
}
