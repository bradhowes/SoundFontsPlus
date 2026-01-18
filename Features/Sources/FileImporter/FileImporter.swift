// Copyright © 2025 Brad Howes. All rights reserved.

import Engine
import FeatureSupport
import UniformTypeIdentifiers

/**
 Feature that imports a SF2 file for use in the synth.
 */
@Reducer
public struct FileImporter {

  @Reducer
  public enum Destination: Equatable {
    case alert(AlertState<Alert>)

    @CasePathable
    public enum Alert: Equatable {
      case addExistingConfirmed(url: URL)
    }
  }

  @ObservableState
  public struct State: Equatable {
    public let types = ["com.braysoftware.sf2", "com.soundblaster.soundfont"].compactMap { UTType($0) } + [.folder]
    public var showChooser: Bool
    @Presents public var destination: Destination.State?

    public var filesPicked: [URL] = []
    public var successes: [URL] = []
    public var failures: [FileImportFailure] = []

    public init(showChooser: Bool = false, destination: Destination.State? = nil) {
      self.showChooser = showChooser
      self.destination = destination
    }
  }

  public enum Action {
    case delegate(Delegate)
    case destination(PresentationAction<Destination.Action>)
    case fileImporterDismissed
    case filesPicked(Result<[URL], Error>)
    case importDupiicateConfirmed(URL)
    case importDuplicateDenied(URL)
    case importNextFile
    case showFileImporter

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

      switch action {

      case .delegate:
        return .none

      case let .destination(.presented(.alert(.addExistingConfirmed(url: url)))):
        return importFile(&state, url: url, allowExisting: true)

      case .fileImporterDismissed:
        state.showChooser = false
        return .none

      case .filesPicked(let result):
        state.showChooser = false
        return filePicked(&state, result: result)

      case .importNextFile:
        return importNextFile(&state)

      case .showFileImporter:
        state.showChooser = true
        return .none

      default:
        return .none
      }
    }
    .ifLet(\.destination, action: \.destination)
  }
}

extension FileImporter {

  private func filePicked(_ state: inout State, result: Result<[URL], Error>) -> Effect<Action> {
    log.debug("filePicked - \(String(describing: result), privacy: .public)")
    switch result {

    case .success(let urls):
      return collectFiles(&state, urls: urls)

    case .failure(let error):
      log.info("failed to pick - \(error.localizedDescription, privacy: .public)")
      state.destination = .alert(.failedToPick(error: error))
      return .none
    }
  }

  private func collectFiles(_ state: inout State, urls: [URL]) -> Effect<Action> {
    log.debug("collectFiles - \(urls)")

    var dirs: [URL] = []

    func addFiles(_ url: [URL]) {
      for url in urls {
        do {
          if url.hasDirectoryPath {
            log.debug("adding directory - \(url)")
            dirs.append(url)
          } else {
            do {
              log.debug("adding file - \(url)")
              let rawTypeId = try url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier
              if let rawTypeId {
                log.debug("rawTypeId: \(rawTypeId, privacy: .public)")
                let typeId = UTType(rawTypeId)
                if let typeId {
                  log.debug("typeId: \(typeId, privacy: .public)")
                  if state.types.contains(typeId) {
                    state.filesPicked.append(url)
                    continue
                  }
                }
              }
              state.failures.append(.init(url, reason: .unknownFileType))
            } catch {
              state.failures.append(.init(url, reason: .unknownFileType))
            }
          }
        }
      }
    }

    addFiles(urls)

    while let url = dirs.popLast() {
      do {
        let urls = try FileManager.default.contentsOfDirectory(
          at: url,
          includingPropertiesForKeys: [.typeIdentifierKey],
          options: [.skipsHiddenFiles]
        )
        addFiles(urls)
      } catch {
        state.failures.append(.init(url, reason: .failedToReadDirectory))
      }
    }

    return importNextFile(&state)
  }

  private func importNextFile(_ state: inout State) -> Effect<Action> {
    if let url = state.filesPicked.popLast() {
      return importFile(&state, url: url, allowExisting: false)
    } else {
      return importFinished(&state)
    }
  }

  private func importFile(_ state: inout State, url: URL, allowExisting: Bool) -> Effect<Action> {

    if !validateSoundFont(url: url) {
      log.info("invalid SF2 file")
      state.failures.append(.init(url, reason: .invalidFile))
      return .send(.importNextFile)
    }

    let kind: SoundFontKind
    do {
      kind = try placeSoundFont(url: url, allowExisting: allowExisting)
    } catch CocoaError.fileWriteFileExists {
      state.destination = .alert(.confirmAddExisting(action: .addExistingConfirmed(url: url), displayName: url.displayName))
      return .none
    } catch {
      state.failures.append(.init(url, reason: .unknownError(error.localizedDescription)))
      return .send(.importNextFile)
    }

    do {
      try SoundFont.add(displayName: String(url.displayName), soundFontKind: kind)
    } catch {
      state.failures.append(.init(url, reason: .invalidFile))
      return .send(.importNextFile)
    }

    state.successes.append(url)
    return .send(.importNextFile)
  }

  private func importFinished(_ state: inout State) -> Effect<Action> {
    let message: String
    switch (state.successes.count, state.failures.count) {
    case (0, 1): message = "Failed to add sound font file."
    case (0, _): message = "Failed to add any sound font files."
    case (1, 0): message = "Added 1 sound font file."
    case (_, 0): message = "Added \(state.successes.count) sound font files."
    case (_, _): message = "Added \(state.successes.count) out of \(state.successes.count + state.failures.count) sound font files."
    }

    state.destination = .alert(.importResults(message: message))
    return .send(.delegate(.importFinished))
  }

  private func validateSoundFont(url: URL) -> Bool {
    url.withSecurityScoping { url in
      var fileInfo = SF2FileInfo(std.string(url.path(percentEncoded: false)))
      return fileInfo.load()
    } ?? false
  }

  private func placeSoundFont(url: URL, allowExisting: Bool) throws -> SoundFontKind {
    @Shared(.copyFileWhenInstalling) var copyFileWhenInstalling

    let location: SoundFontKind
    if copyFileWhenInstalling {
      log.info("copying file to app folder")
      let destination = try copyToFontFilesFolder(url: url, allowExisting: allowExisting)
      location = .installed(filename: destination.lastPathComponent)
    } else {
      log.info("using external file")
      let bookmark = Bookmark(url: url, name: String(url.displayName))
      location = .external(bookmark: bookmark)
    }
    return location
  }

  private func copyToFontFilesFolder(url: URL, allowExisting: Bool) throws -> URL {
    try url.withSecurityScopingThrows { url in
      log.info("copying \(url) to \(fileManager.fontFilesDirectory())")
      let destination = fileManager.fontFilesDirectory().appendingPathComponent(url.lastPathComponent)
      if allowExisting {
        try? fileManager.copyItem(url, destination)
      } else {
        try fileManager.copyItem(url, destination)
      }
      return destination
    }
  }

}

extension FileImporter.Destination.State: Equatable {}
extension FileImporter.Destination.State: _EphemeralState {
  public typealias Action = Alert
}

private let log: Logger = .init(category: "FileImporter")
