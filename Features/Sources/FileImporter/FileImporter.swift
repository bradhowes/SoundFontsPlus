// Copyright © 2025 Brad Howes. All rights reserved.

public import CasePaths
public import ComposableArchitecture
import Engine
public import FeatureSupport
public import UniformTypeIdentifiers
public import SwiftUI

/**
 Feature that imports an SF2 file for use in the synth.
 */
@Reducer
public struct FileImporter {

  @Reducer
  public enum Destination: Equatable {
    case alert(AlertState<Alert>)

    @CasePathable
    public enum Alert: Equatable {
      case multipleImportsConfirmed
      case replaceDuplicateFileConfirmed
    }
  }

  @ObservableState
  public struct State: Equatable {
    public let types = [
      "com.braysoftware.sf2",
      "com.soundblaster.soundfont"
    ].compactMap { UTType($0) } + [
      .folder, .directory
    ]
    public var showPicker: Bool
    @Presents public var destination: Destination.State?

    public var filesPending: [URL] = []
    public var successes: [URL] = []
    public var failures: [FileImportFailure] = []

    public init(showPicker: Bool = false, destination: Destination.State? = nil) {
      self.showPicker = showPicker
      self.destination = destination
    }
  }

  public enum Action {
    case delegate(Delegate)
    case destination(PresentationAction<Destination.Action>)
    case fileImporterDismissed
    case filesPicked(Result<[URL], any Error>)
    case importNextFile
    case showFileImporter

    @CasePathable
    public enum Delegate {
      case importFinished
    }
  }

  public init() {}

  @Dependency(\.fileManager) private var fileManager
  @Dependency(\.dismiss) private var dismiss

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      log.action("FileImporter", action)
      return switch action {
      case .delegate: .none
      case .destination(.presented(.alert(.multipleImportsConfirmed))): importNextFile(&state)
      case .destination(.presented(.alert(.replaceDuplicateFileConfirmed))): importFile(&state, overwrite: true)
      case .destination(.dismiss): dismiss(&state)
      case .fileImporterDismissed: fileImporterDismissed(&state)
      case .filesPicked(let result): filesPicked(&state, result: result)
      case .importNextFile: importNextFile(&state)
      case .showFileImporter: showFileImporter(&state)
      }
    }
    .ifLet(\.destination, action: \.destination)
  }
}

extension FileImporter {

  private func beginImporting(_ state: inout State, urls: [URL]) -> Effect<Action> {
    log.info("beginImporting - \(urls)")

    state.filesPending = []
    state.successes = []
    state.failures = []

    var pending: [URL] = urls

    while let url = pending.popLast() {
      url.withSecurityScoping { url in
        if url.hasDirectoryPath {
          do {
            pending.append(contentsOf: try fileManager.contentsOfDirectory(url))
          } catch {
            recordFailure(&state, .init(url, reason: .failedToReadDirectory))
          }
        } else {
          do {
            if let rawTypeId = try url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier,
               let typeId = UTType(rawTypeId),
               state.types.contains(typeId) {
              state.filesPending.append(url)
            } else {
              recordFailure(&state, .init(url, reason: .unknownFileType))
            }
          } catch {
            recordFailure(&state, .init(url, reason: .unknownFileType))
          }
        }
      }
    }

    if state.filesPending.count > 1 {
      state.destination = .alert(.confirmMultipleImports(action: .multipleImportsConfirmed, count: state.filesPending.count))
      return .none
    }

    try? fileManager.createDirectory(fileManager.fontFilesDirectory())

    return importNextFile(&state)
  }

  private func copyToFontFilesFolder(url: URL, overwrite: Bool) throws -> URL {
    try url.withSecurityScopingThrows { url in
      log.info("copying \(url) to \(fileManager.fontFilesDirectory())")
      let destination = fileManager.fontFilesDirectory().appendingPathComponent(url.lastPathComponent)
      if overwrite {
        try? fileManager.removeItem(destination)
      }
      try fileManager.copyItem(url, destination)
      return destination
    }
  }

  private func dismiss(_ state: inout State) -> Effect<Action> {
    if let actions = state.destination?.alert?.buttons.map(\.action.action),
       actions.contains(.replaceDuplicateFileConfirmed),
       let url = state.filesPending.popLast() {
      state.failures.append(.init(url, reason: .duplicateFile))
      return importNextFile(&state)
    }
    return .none
  }

  private func fileImporterDismissed(_ state: inout State) -> Effect<Action> {
    state.showPicker = false
    return .none
  }

  private func filesPicked(_ state: inout State, result: Result<[URL], any Error>) -> Effect<Action> {
    log.debug("filePicked - \(String(describing: result), privacy: .public)")
    state.showPicker = false
    switch result {

    case .success(let urls):
      return beginImporting(&state, urls: urls)

    case .failure(let error):
      log.info("failed to pick - \(error.localizedDescription, privacy: .public)")
      state.destination = .alert(.failedToPick(error: error))
      return .none
    }
  }

  private func importFile(_ state: inout State, overwrite: Bool = false) -> Effect<Action> {
    guard let url = state.filesPending.popLast() else {
      fatalError("logic error - unexpected empty filePending")
    }

    guard url.startAccessingSecurityScopedResource() else {
      log.info("failed startAccessingSecurityScopedResource on \(url.absoluteString, privacy: .public)")
      return recordFailure(&state, .init(url, reason: .invalidFile))
    }

    defer { url.stopAccessingSecurityScopedResource() }

    if !validateSoundFont(url: url) {
      return recordFailure(&state, .init(url, reason: .invalidFile))
    }

    let kind: SoundFontKind
    do {
      kind = try placeSoundFont(url: url, overwrite: overwrite)
    } catch CocoaError.fileWriteFileExists {
      state.filesPending.append(url)
      state.destination = .alert(.replaceDuplicateFile(
        action: .replaceDuplicateFileConfirmed,
        displayName: url.lastPathComponent
      ))
      return .none
    } catch {
      return recordFailure(&state, .init(url, reason: .unknownError(error.localizedDescription)))
    }

    do {
      try SoundFont.add(displayName: String(url.displayName), soundFontKind: kind)
    } catch {
      return recordFailure(&state, .init(url, reason: .invalidFile))
    }

    return recordSuccess(&state, url)
  }

  private func importFinished(_ state: inout State) -> Effect<Action> {
    state.destination = .alert(.importResults(summary: Self.generateImportSummary(state.successes, state.failures)))
    return .send(.delegate(.importFinished))
  }

  private func importNextFile(_ state: inout State) -> Effect<Action> {
    state.filesPending.isEmpty ? importFinished(&state) : importFile(&state)
  }

  private func placeSoundFont(url: URL, overwrite: Bool) throws -> SoundFontKind {
    @Shared(.copyFileWhenInstalling) var copyFileWhenInstalling

    let location: SoundFontKind
    if copyFileWhenInstalling {
      log.info("copying file to app folder")
      let destination = try copyToFontFilesFolder(url: url, overwrite: overwrite)
      location = .installed(filename: destination.lastPathComponent)
    } else {
      log.info("using external file")
      let bookmark = Bookmark(url: url, name: String(url.displayName))
      location = .external(bookmark: bookmark)
    }
    return location
  }

  @discardableResult
  private func recordFailure(_ state: inout State, _ failure: FileImportFailure) -> Effect<Action> {
    state.failures.append(failure)
    return .send(.importNextFile)
  }

  @discardableResult
  private func recordSuccess(_ state: inout State, _ url: URL) -> Effect<Action> {
    state.successes.append(url)
    return .send(.importNextFile)
  }

  private func showFileImporter(_ state: inout State) -> Effect<Action> {
    state.showPicker = true
    return .none
  }

  private func validateSoundFont(url: URL) -> Bool {
    url.withSecurityScoping { url in
      var fileInfo = SF2FileInfo(std.string(url.path(percentEncoded: false)))
      return fileInfo.load()
    } ?? false
  }
}

extension FileImporter {

  static func generateImportSummary(_ successes: [URL], _ failures: [FileImportFailure]) -> String {

    func failureClause(prelude: String? = nil) -> String {
      var contents: String = prelude?.appending("\n") ?? ""
      if !failures.isEmpty {
        for each in failures {
          contents.append("- \(each.url.deletingPathExtension().lastPathComponent): \(each.reason.tag)\n")
        }
      }
      return contents
    }

    func successClause(prelude: String? = nil) -> String {
      var contents: String = prelude?.appending("\n") ?? ""
      if !successes.isEmpty {
        for each in successes {
          contents.append("- \(each.deletingPathExtension().lastPathComponent)\n")
        }
      }
      return contents
    }

    let summary: String
    switch (successes.count, failures.count) {
    case (0, 1): summary = failureClause(prelude: "Failed to add sound font file:")
    case (0, _): summary = failureClause(prelude: "Failed to add any sound font files:")
    case (1, 0): summary = "Added 1 sound font file."
    case (_, 0): summary = successClause(prelude: "Added \(successes.count) sound font files:")
    case (_, _):
      summary = successClause(
        prelude: "Added \(successes.count) out of \(successes.count + failures.count) sound font files:"
      ) + failureClause(prelude: "Failure(s):")
    }

    return summary
  }
}

extension FileImporter.Destination.State: Equatable {}
extension FileImporter.Destination.State: _EphemeralState {
  public typealias Action = Alert
}

private let log: Logger = .init(category: "FileImporter")
