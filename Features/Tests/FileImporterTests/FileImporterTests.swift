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

  @Test
  func showFileImporter() async throws {
    let store = store()
    await store.send(.showFileImporter) {
      $0.showChooser = true
    }
    await store.send(.fileImporterDismissed) {
      $0.showChooser = false
    }
  }

  @Test
  func filePickedFailure() async throws {
    let store = store()
    await store.send(.showFileImporter) {
      $0.showChooser = true
    }

    let err = TestError.failedToDoSomething("oh no")
    await store.send(.filesPicked(.failure(err))) {
      $0.showChooser = false
      $0.destination = .alert(.failedToPick(error: err))
    }
  }

  @Test
  func filePickedOneUnknownFileType() async throws {
    let store = store()
    await store.send(.showFileImporter) {
      $0.showChooser = true
    }

    let url = SF2ResourceTag.fluidFont.url.appendingPathComponent("foo")
    await store.send(.filesPicked(.success([url]))) {
      $0.showChooser = false
      $0.failures = [.init(url, reason: .invalidFile)]
    }

    await store.receive(\.importNextFile) {
      $0.destination = .alert(.importResults(message: "Failed to add sound font file."))
    }

    await store.receive(\.delegate, .importFinished)
  }

  @Test
  func filePickedMultipleUnknownFileTypes() async throws {
    let store = store()
    await store.send(.showFileImporter) {
      $0.showChooser = true
    }

    let url1 = SF2ResourceTag.fluidFont.url.appendingPathComponent("foo")
    let url2 = SF2ResourceTag.fluidFont.url.appendingPathComponent("bar")
    await store.send(.filesPicked(.success([url1, url2]))) {
      $0.showChooser = false
      $0.filesPending = [url1]
      $0.failures = [
        .init(url2, reason: .invalidFile)
      ]
    }

    await store.receive(\.importNextFile) {
      $0.filesPending = []
      $0.failures = [
        .init(url2, reason: .invalidFile),
        .init(url1, reason: .invalidFile)
      ]
    }

    await store.receive(\.importNextFile) {
      $0.destination = .alert(.importResults(message: "Failed to add any sound font files."))
    }

    await store.receive(\.delegate, .importFinished)
  }

  @Test
  func filePickedAdded() async throws {
    let mockSharedDocumentsDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try? FileManager.default.createDirectory(at: mockSharedDocumentsDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: mockSharedDocumentsDirectory) }

    @Shared(.copyFileWhenInstalling) var copyFileWhenInstalling = true
    let store = TestStoreOf<FileImporter>(initialState: .init()) {
      FileImporter()
    } withDependencies: {
      let uuid = UUID()
      let path = FileManager.default.temporaryDirectory.appendingPathComponent(uuid.uuidString)
      try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
      $0.fileManager = .liveValue
      $0.fileManager.fontFilesDirectory = {
        path
      }
      $0.fileManager.fontFilePath = { path.appendingPathComponent($0, isDirectory: false) }
      $0.defaultDatabase = TestSupport.testDatabase()
    }

    let lastPathComponent = "filePickedAdded.sf2"
    let url = SF2ResourceTag.fluidFont.url
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(lastPathComponent)
    try? FileManager.default.removeItem(at: tmp)
    try FileManager.default.copyItem(at: url, to: tmp)

    let dst = FileManager.default.fontFilesDirectory.appendingPathComponent(lastPathComponent)
    try? FileManager.default.removeItem(at: dst)

    await store.send(.filesPicked(.success([tmp]))) {
      $0.showChooser = false
      // $0.destination = .alert(.addedSummary(displayName: "BlahBlah"))
      $0.successes = [tmp]
    }

    await store.receive(\.importNextFile) {
      $0.destination = .alert(.importResults(message: "Added 1 sound font file."))
    }

    await store.receive(\.delegate, .importFinished)
  }

  @Test
  func filePickedAddedNoCopy() async throws {
    @Shared(.copyFileWhenInstalling) var copyFileWhenInstalling = false
    let store = TestStoreOf<FileImporter>(initialState: .init()) {
      FileImporter()
    } withDependencies: {
      $0.fileManager = .liveValue
      $0.defaultDatabase = TestSupport.testDatabase()
    }

    let lastPathComponent = "filePickedAddedNoCopy.sf2"
    let url = SF2ResourceTag.fluidFont.url
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(lastPathComponent)
    try? FileManager.default.removeItem(at: tmp)
    try FileManager.default.copyItem(at: url, to: tmp)

    let dst = FileManager.default.fontFilesDirectory.appendingPathComponent(lastPathComponent)
    try? FileManager.default.removeItem(at: dst)

    await store.send(.filesPicked(.success([tmp]))) {
      $0.showChooser = false
      $0.successes = [tmp]
    }

    await store.receive(\.importNextFile) {
      $0.destination = .alert(.importResults(message: "Added 1 sound font file."))
    }

    await store.receive(\.delegate, .importFinished)
  }

  @Test
  func filePickedInvalidFormat() async throws {
    @Shared(.copyFileWhenInstalling) var copyFileWhenInstalling = false
    let store = TestStoreOf<FileImporter>(initialState: .init()) {
      FileImporter()
    } withDependencies: {
      $0.fileManager = .liveValue
      $0.defaultDatabase = TestSupport.testDatabase()
    }

    let lastPathComponent = "filePickedInvalidFormat.sf2"
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(lastPathComponent)
    try? FileManager.default.removeItem(at: tmp)
    try Data("123123123".utf8).write(to: tmp)

    let dst = FileManager.default.fontFilesDirectory.appendingPathComponent(lastPathComponent)
    try? FileManager.default.removeItem(at: dst)

    await store.send(.filesPicked(.success([tmp]))) {
      $0.showChooser = false
      $0.failures = [FileImportFailure(tmp, reason: .invalidFile)]
    }

    await store.receive(\.importNextFile) {
      $0.destination = .alert(.importResults(message: "Failed to add sound font file."))
    }

    await store.receive(\.delegate, .importFinished)
  }

  @Test(
    .dependencies {
      $0.fileManager = .liveValue
      $0.defaultDatabase = TestSupport.testDatabase()
    }
  )
  func filePickedDuplicateFiles() async throws {
    @Shared(.copyFileWhenInstalling) var copyFileWhenInstalling
    $copyFileWhenInstalling.withLock { $0 = true }

    let store = store()
    await store.send(.showFileImporter) {
      $0.showChooser = true
    }

    let url1 = SF2ResourceTag.fluidFont.url
    var dst = FileManager.default.fontFilesDirectory.appendingPathComponent(url1.lastPathComponent)
    try? FileManager.default.removeItem(at: dst)

    let url2 = SF2ResourceTag.fluidFont.url
    dst = FileManager.default.fontFilesDirectory.appendingPathComponent(url2.lastPathComponent)
    try? FileManager.default.removeItem(at: dst)

    await store.send(.filesPicked(.success([url1, url2]))) {
      $0.showChooser = false
      $0.filesPending = [url1]
      $0.destination = nil
      $0.successes = [url2]
    }

    await store.receive(\.importNextFile) {
      $0.filesPending = []
      $0.failures = [.init(url1, reason: .duplicateFile)]
    }

    await store.receive(\.importNextFile) {
      $0.destination = .alert(
        .importResults(message: "Added 1 out of 2 sound font files.")
      )
    }

    await store.receive(\.delegate, .importFinished)
  }

  @Test
  func failedToPick() async throws {
    struct MockError: Error {}
    let _: AlertState<FileImporter.Action> = .failedToPick(error: MockError())
  }

  @Test
  func importResults() async throws {
    let _: AlertState<FileImporter.Action> = .importResults(message: "Everything")
  }
}

private enum TestError: Error {
  case failedToDoSomething(String)
}
