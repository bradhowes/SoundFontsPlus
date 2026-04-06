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
  @Shared(.copyFileWhenInstalling) var copyFileWhenInstalling = true

  func store() -> TestStoreOf<FileImporter> {
    TestStoreOf<FileImporter>(initialState: .init()) {
      FileImporter()
    }
  }

  @Test
  func showFileImporter() async throws {
    let store = store()
    await store.send(.showFileImporter) {
      $0.showPicker = true
    }
    await store.send(.fileImporterDismissed) {
      $0.showPicker = false
    }
  }

  @Test
  func filePickedFailure() async throws {
    let store = store()
    await store.send(.showFileImporter) {
      $0.showPicker = true
    }

    let err = TestError.failedToDoSomething("oh no")
    await store.send(.filesPicked(.failure(err))) {
      $0.showPicker = false
      $0.destination = .alert(.failedToPick(error: err))
    }
  }

  @Test(
    .dependencies {
      $0.fileManager = .liveValue
    }
  )
  func filePickedOneUnknownFileType() async throws {
    let store = store()
    await store.send(.showFileImporter) {
      $0.showPicker = true
    }

    let url = SF2ResourceTag.fluidFont.url.appendingPathComponent("foo")
    await store.send(.filesPicked(.success([url]))) {
      $0.showPicker = false
      $0.failures = [.init(url, reason: .unknownFileType)]
      $0.destination = .alert(.importResults(summary: FileImporter.generateImportSummary($0.successes, $0.failures)))
    }
    await store.receive(\.delegate, .importFinished)
  }

  @Test(
    .dependencies {
      $0.fileManager = .liveValue
    }
  )
  func filePickedMultipleUnknownFileTypes() async throws {
    let store = store()
    await store.send(.showFileImporter) {
      $0.showPicker = true
    }

    let url1 = SF2ResourceTag.fluidFont.url.appendingPathComponent("foo")
    let url2 = SF2ResourceTag.fluidFont.url.appendingPathComponent("bar")
    await store.send(.filesPicked(.success([url1, url2]))) {
      $0.showPicker = false
      $0.filesPending = []
      $0.failures = [
        .init(url2, reason: .unknownFileType),
        .init(url1, reason: .unknownFileType)
      ]
      $0.destination = .alert(.importResults(summary: FileImporter.generateImportSummary($0.successes, $0.failures)))
    }

    await store.receive(\.delegate, .importFinished)
  }

  @Test
  func filePickedAdded() async throws {
    let mockSharedDocumentsDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try? FileManager.default.createDirectory(at: mockSharedDocumentsDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: mockSharedDocumentsDirectory) }

    $copyFileWhenInstalling.withLock { $0 = true }
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
      $0.showPicker = false
      // $0.destination = .alert(.addedSummary(displayName: "BlahBlah"))
      $0.successes = [tmp]
    }

    await store.receive(\.importNextFile) {
      $0.destination = .alert(.importResults(summary: "Added 1 sound font file."))
    }

    await store.receive(\.delegate, .importFinished)
  }

  @Test
  func filePickedAddedNoCopy() async throws {
    $copyFileWhenInstalling.withLock { $0 = false }

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
      $0.showPicker = false
      $0.successes = [tmp]
    }

    await store.receive(\.importNextFile) {
      $0.destination = .alert(.importResults(summary: "Added 1 sound font file."))
    }

    await store.receive(\.delegate, .importFinished)
  }

  @Test
  func filePickedInvalidFormat() async throws {
    $copyFileWhenInstalling.withLock { $0 = false }
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
      $0.showPicker = false
      $0.failures = [FileImportFailure(tmp, reason: .invalidFile)]
    }

    await store.receive(\.importNextFile) {
      $0.destination = .alert(.importResults(summary: FileImporter.generateImportSummary($0.successes, $0.failures)))
    }

    await store.receive(\.delegate, .importFinished)
  }

  @Test(
    .dependencies {
      $0.fileManager = .liveValue
      $0.defaultDatabase = TestSupport.testDatabase()
    }
  )
  func filePickedMultipleFilesCancelConfirm() async throws {
    @Dependency(\.fileManager) var fileManager
    $copyFileWhenInstalling.withLock { $0 = true }

    let store = store()
    await store.send(.showFileImporter) {
      $0.showPicker = true
    }

    let uuid = "filePickedMultipleFilesCancelConfirm"
    let fileName = uuid + ".sf2"
    let tmp = FileManager.default.temporaryDirectory.appending(path: uuid, directoryHint: .isDirectory)
    try? fileManager.createDirectory(tmp)
    let url = tmp.appending(path: fileName)
    try? fileManager.copyItem(SF2ResourceTag.fluidFont.url, url)
    try? fileManager.removeItem(fileManager.fontFilesDirectory().appendingPathComponent(fileName))

    await store.send(.filesPicked(.success([url, url]))) {
      $0.showPicker = false
      $0.filesPending = [url, url]
      $0.destination = .alert(.confirmMultipleImports(action: .multipleImportsConfirmed, count: 2))
    }

    await store.send(\.destination.dismiss) {
      $0.destination = nil
    }
  }

  @Test(
    .dependencies {
      $0.fileManager = .liveValue
      $0.defaultDatabase = TestSupport.testDatabase()
    }
  )
  func filePickedDuplicateFilesCancel() async throws {
    @Dependency(\.fileManager) var fileManager
    $copyFileWhenInstalling.withLock { $0 = true }

    let store = store()
    await store.send(.showFileImporter) {
      $0.showPicker = true
    }

    let uuid = "filePickedDuplicateFilesCancel"
    let fileName = uuid + ".sf2"
    let tmp = FileManager.default.temporaryDirectory.appending(path: uuid, directoryHint: .isDirectory)
    try? fileManager.createDirectory(tmp)
    let url = tmp.appending(path: fileName)
    try? fileManager.copyItem(SF2ResourceTag.fluidFont.url, url)
    try? fileManager.removeItem(fileManager.fontFilesDirectory().appendingPathComponent(fileName))

    await store.send(.filesPicked(.success([url, url]))) {
      $0.showPicker = false
      $0.filesPending = [url, url]
      $0.destination = .alert(.confirmMultipleImports(action: .multipleImportsConfirmed, count: 2))
    }

    await store.send(\.destination.alert.multipleImportsConfirmed) {
      $0.destination = nil
      $0.filesPending = [url]
      $0.successes = [url]
    }

    await store.receive(\.importNextFile) {
      $0.destination = .alert(.replaceDuplicateFile(
        action: .replaceDuplicateFileConfirmed,
        displayName: url.lastPathComponent
      ))
    }

    await store.send(\.destination.dismiss) {
      $0.failures.append(.init(url, reason: .duplicateFile))
      $0.filesPending = []
      $0.destination = .alert(.importResults(summary: FileImporter.generateImportSummary($0.successes, $0.failures)))
    }

    await store.receive(\.delegate, .importFinished)
  }

  @Test(
    .dependencies {
      $0.fileManager = .liveValue
      $0.defaultDatabase = TestSupport.testDatabase()
    }
  )
  func filePickedDuplicateFilesAccept() async throws {
    @Dependency(\.fileManager) var fileManager
    $copyFileWhenInstalling.withLock { $0 = true }

    let store = store()
    await store.send(.showFileImporter) {
      $0.showPicker = true
    }

    let uuid = "filePickedDuplicateFilesAccept"
    let fileName = uuid + ".sf2"
    let tmp = FileManager.default.temporaryDirectory.appending(path: uuid, directoryHint: .isDirectory)
    try? fileManager.createDirectory(tmp)
    let url = tmp.appending(path: fileName)
    try? fileManager.copyItem(SF2ResourceTag.fluidFont.url, url)
    try? fileManager.removeItem(fileManager.fontFilesDirectory().appendingPathComponent(fileName))

    await store.send(.filesPicked(.success([url, url]))) {
      $0.showPicker = false
      $0.filesPending = [url, url]
      $0.destination = .alert(.confirmMultipleImports(action: .multipleImportsConfirmed, count: 2))
    }

    await store.send(\.destination.alert.multipleImportsConfirmed) {
      $0.destination = nil
      $0.filesPending = [url]
      $0.successes = [url]
    }

    await store.receive(\.importNextFile) {
      $0.destination = .alert(.replaceDuplicateFile(
        action: .replaceDuplicateFileConfirmed,
        displayName: url.lastPathComponent
      ))
    }

    await store.send(\.destination.alert.replaceDuplicateFileConfirmed) {
      $0.successes.append(url)
      $0.filesPending = []
      $0.destination = nil
      // $0.destination = .alert(.importResults(summary: FileImporter.generateImportSummary($0.successes, $0.failures)))
    }

    await store.receive(\.importNextFile) {
      $0.destination = .alert(.importResults(summary: FileImporter.generateImportSummary($0.successes, $0.failures)))
    }

    await store.receive(\.delegate, .importFinished)
  }

  @Test(
    .dependencies {
      $0.fileManager = .testValue
      $0.fileManager.contentsOfDirectory = { _ in [] }
    }
  )
  func filePickedEmptyDirectory() async throws {
    let store = TestStoreOf<FileImporter>(initialState: .init()) {
      FileImporter()
    } withDependencies: {
      $0.fileManager = .liveValue
      $0.defaultDatabase = TestSupport.testDatabase()
    }

    let tmp = FileManager.default.temporaryDirectory.appending(path: "filePickedEmptyDirectory", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

    await store.send(.filesPicked(.success([tmp]))) {
      $0.showPicker = false
      $0.destination = .alert(.importResults(summary: FileImporter.generateImportSummary($0.successes, $0.failures)))
    }

    await store.receive(\.delegate, .importFinished)
  }

  @Test(
    .dependencies {
      $0.fileManager = .testValue
      $0.fileManager.contentsOfDirectory = { _ in [] }
    }
  )
  func filePickedDirectory() async throws {
    let store = TestStoreOf<FileImporter>(initialState: .init()) {
      FileImporter()
    } withDependencies: {
      $0.fileManager = .liveValue
      $0.defaultDatabase = TestSupport.testDatabase()
    }

    let dir = FileManager.default.temporaryDirectory.appending(path: "filePickedDirectory", directoryHint: .isDirectory)
    do {
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    } catch {
      print("failed to create directory at \(dir)")
    }

    let url1 = SF2ResourceTag.freeFont.url
    let dst = dir.appending(path: "filePickedDirectory.sf2", directoryHint: .notDirectory)
    do {
      try FileManager.default.copyItem(at: url1, to: dst)
    } catch {
      print("*** failed to copy \(url1) to \(dst) - \(error.localizedDescription)")
    }

    try? FileManager.default.removeItem(at: FileManager.default.fontFilesDirectory.appending(path: "filePickedDirectory.sf2"))

    await store.send(.filesPicked(.success([dir]))) {
      $0.showPicker = false
      $0.successes = [dst]
    }

    await store.receive(\.importNextFile) {
      $0.filesPending = []
      $0.destination = .alert(.importResults(summary: FileImporter.generateImportSummary($0.successes, $0.failures)))
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
    let _: AlertState<FileImporter.Action> = .importResults(summary: "Everything")
  }
}

private enum TestError: Error {
  case failedToDoSomething(String)
}
