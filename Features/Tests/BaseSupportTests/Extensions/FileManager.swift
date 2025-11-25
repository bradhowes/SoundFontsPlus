// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import Testing

@testable import BaseSupport

@Suite
struct FileManagerTests {

  @Test
  func sharedDocumentsDirectory() async throws {
    let url = FileManager.default.sharedDocumentsDirectory
    #expect(url.path() != "")
    #expect(FileManager.default.fileExists(atPath: url.path()))
    try FileManager.default.removeItem(atPath: url.path())
    #expect(!FileManager.default.fileExists(atPath: url.path()))
    #expect(FileManager.default.sharedDocumentsDirectory.path() != "")
  }

  @Test
  func hasCloudDirectory() async throws {
    #expect(FileManager.default.hasCloudDirectory == (FileManager.default.ubiquityIdentityToken != nil))
  }

  @Test
  func localDocumentsDirectory() async throws {
    #expect(FileManager.default.localDocumentsDirectory.path() != "")
  }

  @Test
  func cloudDocumentsDirectory() async throws {
    #expect(FileManager.default.cloudDocumentsDirectory == nil)
  }

  @Test
  func fileSizeOfUrl() async throws {
    #expect(FileManager.default.fileSizeOf(url: Bundle.main.bundleURL) != 0)
    // swiftlint:disable:next force_unwrapping
    #expect(FileManager.default.fileSizeOf(url: URL(filePath: "blahblahblah")!) == 0)
  }

  @Test
  func fileManagerLiveClient() async throws {
    let uat = FileManagerClient.liveValue
    #expect(uat.hasCloudDirectory() == FileManager.default.hasCloudDirectory)
    #expect(uat.localDocumentsDirectory() == FileManager.default.localDocumentsDirectory)
    #expect(uat.sharedDocumentsDirectory() == FileManager.default.sharedDocumentsDirectory)
    #expect(uat.cloudDocumentsDirectory() == FileManager.default.cloudDocumentsDirectory)
    #expect(uat.fileSizeOf(Bundle.main.bundleURL) == FileManager.default.fileSizeOf(url: Bundle.main.bundleURL))
    #expect(uat.isUbiquitousItem(Bundle.main.bundleURL) == FileManager.default.isUbiquitousItem(at: Bundle.main.bundleURL))
  }

  @Test
  func fileManagerPreviewClient() async throws {
    let uat = FileManagerClient.previewValue
    #expect(uat.hasCloudDirectory() == false)
    #expect(uat.localDocumentsDirectory() == FileManager.default.localDocumentsDirectory)
    #expect(uat.sharedDocumentsDirectory() == FileManager.default.sharedDocumentsDirectory)
    #expect(uat.cloudDocumentsDirectory() == nil)
    #expect(uat.fileSizeOf(Bundle.main.bundleURL) == FileManager.default.fileSizeOf(url: Bundle.main.bundleURL))
    #expect(uat.isUbiquitousItem(Bundle.main.bundleURL) == false)
  }
}
