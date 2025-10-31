// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import SF2Resources
import SnapshotTesting
import Testing
import TestSupport

@testable import FileImporter

@Suite(
  .dependencies {
    $0.fileManager = .testValue
  }
)
@MainActor
struct FileImporterTests {

  func store() -> TestStoreOf<FileImporter> {
    TestStoreOf<FileImporter>(initialState: .init()) {
      FileImporter()
    }
  }

  @Test func showFileImporter() async throws {
    let store = store()
    await store.send(.showFileImporter) {
      $0.showChooser = true
    }
    await store.send(.filePickerCancelled) {
      $0.showChooser = false
    }
  }

  @Test func filePickedFailure() async throws {
    let store = store()
    await store.send(.showFileImporter) {
      $0.showChooser = true
    }

    let err = TestError.failedToDoSomething("oh no")
    await store.send(.filePicked(.failure(err))) {
      $0.showChooser = false
      $0.destination = .alert(.failedToPick(error: err))
    }
  }

  @Test func filePickedAlreadyImported() async throws {
    let store = TestStoreOf<FileImporter>(initialState: .init()) {
      FileImporter()
    } withDependencies: {
      $0.fileManager = .liveValue
      $0.defaultDatabase = try! appDatabase()
    }
    await store.send(.showFileImporter) {
      $0.showChooser = true
    }

    let url = SF2ResourceTag.fluidFont.url
    await store.send(.filePicked(.success(url))) {
      $0.showChooser = false
      $0.destination = .alert(.fileAlreadyImported(url: url))
    }
  }

  @Test func filePickedInvalidFile() async throws {
    let store = store()
    await store.send(.showFileImporter) {
      $0.showChooser = true
    }

    let url = SF2ResourceTag.fluidFont.url.appendingPathComponent("foo")
    await store.send(.filePicked(.success(url))) {
      $0.showChooser = false
      $0.destination = .alert(.invalidSoundFontFormat(displayName: "foo"))
    }
  }

  @Test func filePickedGenericFailure() async throws {
    let lastPathComponent = "BlahBlah.sf2"
    let url = SF2ResourceTag.fluidFont.url.appendingPathComponent("foo")
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(lastPathComponent)
    try? FileManager.default.copyItem(at: url, to: tmp)
    let dst = FileManager.default.sharedDocumentsDirectory.appendingPathComponent(lastPathComponent)
    try? FileManager.default.copyItem(at: tmp, to: dst)

    let err = NSError(
      domain: "NSCocoaErrorDomain",
      code: 256,
      userInfo: [
        "NSFilePath": tmp.path,
        "NSURL": tmp,
        "NSUnderlyingError": NSError(domain: "NSPOSIXErrorDomain", code: 20, userInfo: nil),
      ]
    )

    let store = TestStoreOf<FileImporter>(initialState: .init()) {
      FileImporter()
    } withDependencies: {
      $0.fileManager = .liveValue
      $0.fileManager.copyItem = { _, _ in throw err}
    }

    await store.send(.showFileImporter) {
      $0.showChooser = true
    }

    await store.send(.filePicked(.success(tmp))) {
      $0.showChooser = false
      $0.destination = .alert(.genericFailureToImport(displayName: "BlahBlah", error: err))
    }
  }

  @Test func filePickedAdded() async throws {
    @Shared(.copyFileWhenInstalling) var copyFileWhenInstalling = true
    let store = TestStoreOf<FileImporter>(initialState: .init()) {
      FileImporter()
    } withDependencies: {
      $0.fileManager = .liveValue
      $0.defaultDatabase = try! appDatabase()
      // $0.fileManager.copyItem = { _, _ in throw err}
    }

    let lastPathComponent = "BlahBlah.sf2"
    let url = SF2ResourceTag.fluidFont.url
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(lastPathComponent)
    try? FileManager.default.copyItem(at: url, to: tmp)

    let dst = FileManager.default.sharedDocumentsDirectory.appendingPathComponent(lastPathComponent)
    try? FileManager.default.removeItem(at: dst)

    await store.send(.filePicked(.success(tmp))) {
      $0.showChooser = false
      $0.destination = .alert(.addedSummary(displayName: "BlahBlah"))
    }
  }

  @Test func filePickedAddedNoCopy() async throws {
    @Shared(.copyFileWhenInstalling) var copyFileWhenInstalling = false
    let store = TestStoreOf<FileImporter>(initialState: .init()) {
      FileImporter()
    } withDependencies: {
      $0.fileManager = .liveValue
      $0.defaultDatabase = try! appDatabase()
      // $0.fileManager.copyItem = { _, _ in throw err}
    }

    let lastPathComponent = "BlahBlah.sf2"
    let url = SF2ResourceTag.fluidFont.url
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(lastPathComponent)
    try? FileManager.default.copyItem(at: url, to: tmp)

    let dst = FileManager.default.sharedDocumentsDirectory.appendingPathComponent(lastPathComponent)
    try? FileManager.default.removeItem(at: dst)

    await store.send(.filePicked(.success(tmp))) {
      $0.showChooser = false
      $0.destination = .alert(.addedSummary(displayName: "BlahBlah"))
    }
  }
}

fileprivate enum TestError: Error {
  case failedToDoSomething(String)
}
