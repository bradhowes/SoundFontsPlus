import Foundation
import Testing

@testable import BaseSupport

@Suite(
  //  .dependencies {
  //    $0.defaultDatabase = try appDatabase()
  //  },
  //  .snapshots(record: .failed)
)
struct FileManagerTests {

  @Test func sharedDocumentsDirectory() async throws {
    let url = FileManager.default.sharedDocumentsDirectory
    #expect(url.path() != "")
    #expect(FileManager.default.fileExists(atPath: url.path()))
    try FileManager.default.removeItem(atPath: url.path())
    #expect(!FileManager.default.fileExists(atPath: url.path()))
    #expect(FileManager.default.sharedDocumentsDirectory.path() != "")
  }

  @Test func hasCloudDirectory() async throws {
    #expect(FileManager.default.hasCloudDirectory == (FileManager.default.ubiquityIdentityToken != nil))
  }

  @Test func localDocumentsDirectory() async throws {
    #expect(FileManager.default.localDocumentsDirectory.path() != "")
  }

  @Test func cloudDocumentsDirectory() async throws {
    #expect(FileManager.default.cloudDocumentsDirectory == nil)
  }

  @Test func fileSizeOfUrl() async throws {
    #expect(FileManager.default.fileSizeOf(url: Bundle.main.bundleURL) != 0)
    #expect(FileManager.default.fileSizeOf(url: URL(filePath: "blahblahblah")!) == 0)
  }
}
