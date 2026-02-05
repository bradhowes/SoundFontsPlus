// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import Testing

@testable import BaseSupport

@Suite(.serialized)
struct FileManagerTests {

  @Test
  func sharedDocumentsDirectory() async throws {
    let url = FileManager.default.sharedDocumentsDirectory
    #expect(url.path(percentEncoded: false) != "")
    #expect(FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
    try? FileManager.default.removeItem(atPath: url.path(percentEncoded: false))
    #expect(!FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
    #expect(FileManager.default.sharedDocumentsDirectory.path(percentEncoded: false) != "")
  }

  @Test
  func localDocumentsDirectory() async throws {
    #expect(FileManager.default.localDocumentsDirectory.path(percentEncoded: false) != "")
  }

  @Test
  func cloudDocumentsDirectory() async throws {
    #expect(FileManager.default.cloudDocumentsDirectory == nil)
  }

  @Test
  func fileSizeOfUrl() async throws {
    #expect(FileManager.default.fileSizeOf(url: Bundle.main.bundleURL) != 0)
    #expect(FileManager.default.fileSizeOf(url: URL(filePath: "blahblahblah")!) == 0)
  }

  @Test
  func fileManagerLiveClient() async throws {
    let uat = FileManagerClient.liveValue
    #expect(uat.localDocumentsDirectory() == FileManager.default.localDocumentsDirectory)
    #expect(uat.sharedDocumentsDirectory() == FileManager.default.sharedDocumentsDirectory)
    #expect(uat.cloudDocumentsDirectory() == FileManager.default.cloudDocumentsDirectory)
    #expect(uat.fileSizeOf(Bundle.main.bundleURL) == FileManager.default.fileSizeOf(url: Bundle.main.bundleURL))
    #expect(uat.isUbiquitousItem(Bundle.main.bundleURL) == FileManager.default.isUbiquitousItem(at: Bundle.main.bundleURL))
  }

  @Test
  func fileManagerPreviewClient() async throws {
    let uat = FileManagerClient.previewValue
    #expect(uat.localDocumentsDirectory() == FileManager.default.localDocumentsDirectory)
    #expect(uat.sharedDocumentsDirectory() == FileManager.default.sharedDocumentsDirectory)
    #expect(uat.cloudDocumentsDirectory() == nil)
    #expect(uat.fileSizeOf(Bundle.main.bundleURL) == FileManager.default.fileSizeOf(url: Bundle.main.bundleURL))
    #expect(uat.isUbiquitousItem(Bundle.main.bundleURL) == false)
  }
}
