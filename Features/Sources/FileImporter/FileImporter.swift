// Copyright © 2025 Brad Howes. All rights reserved.

import Engine
import FeatureSupport
import UniformTypeIdentifiers

private let log = Logger(category: "FileImporter")

@Reducer
public struct FileImporter {

  @Reducer
  public enum Destination: Equatable {
    case alert(AlertState<Alert>)

    @CasePathable
    public enum Alert: Equatable {
      case importDuplicateFileConfirmed(displayName: String, url: URL)
    }
  }

  @ObservableState
  public struct State: Equatable {
    public let types = ["com.braysoftware.sf2", "com.soundblaster.soundfont"].compactMap { UTType($0) }
    public var showChooser: Bool
    @Presents public var destination: Destination.State?

    public init(showChooser: Bool = false, destination: Destination.State? = nil) {
      self.showChooser = showChooser
      self.destination = destination
    }
  }

  public enum Action {
    case destination(PresentationAction<Destination.Action>)
    case filePickerCancelled
    case filePicked(Result<URL, Error>)
    case showFileImporter
  }

  public init() {}

  @Dependency(\.fileManager) private var fileManager
  @Dependency(\.dismiss) private var dismiss

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      log.debug("action: \(action)")

      switch action {

      case let .destination(.presented(.alert(.importDuplicateFileConfirmed(displayName: displayName, url: url)))):
        return importFile(&state, displayName: displayName, url: url, allowExisting: true)

      case .filePickerCancelled:
        state.showChooser = false
        return .none

      case let .filePicked(result):
        state.showChooser = false
        return filePicked(&state, result: result)

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

  private func filePicked(_ state: inout State, result: Result<URL, Error>) -> Effect<Action> {

    switch result {

    case .success(let url):
      let displayName = String(url.lastPathComponent.withoutExtension)
      log.info("picked \(displayName) - \(url)")
      return importFile(&state, displayName: displayName, url: url)

    case .failure(let error):
      log.info("failed to pick - \(error.localizedDescription)")
      state.destination = .alert(.failedToPick(error: error))
      return .none
    }
  }

  private func importFile(
    _ state: inout State,
    displayName: String,
    url: URL,
    allowExisting: Bool = false
  ) -> Effect<Action> {
    if !validateSoundFont(url: url) {
      log.info("invalid SF2 file")
      state.destination = .alert(.invalidSoundFontFormat(displayName: displayName))
      return .none
    }

    let kind: SoundFontKind
    do {
      kind = try placeSoundFont(&state, displayName: displayName, source: url, allowExisting: allowExisting)
    } catch CocoaError.fileWriteFileExists {
      state.destination = .alert(
        .confirmAddExisting(
          action: .importDuplicateFileConfirmed(displayName: displayName, url: url),
          displayName: displayName
        )
      )
      return .none
    } catch {
      state.destination = .alert(.genericFailureToImport(displayName: displayName, error: error))
      return .none
    }

    do {
      try SoundFont.add(displayName: displayName, soundFontKind: kind)
    } catch {
      state.destination = .alert(.genericFailureToImport(displayName: displayName, error: error))
      return .none
    }

    state.destination = .alert(.addedSummary(displayName: displayName))

    return .none
  }

  private func validateSoundFont(url: URL) -> Bool {
    url.withSecurityScoping { url in
      var fileInfo = SF2FileInfo(std.string(url.path(percentEncoded: false)))
      return fileInfo.load()
    } ?? false
  }

  private func placeSoundFont(
    _ state: inout State,
    displayName: String,
    source: URL,
    allowExisting: Bool
  ) throws -> SoundFontKind {
    @Shared(.copyFileWhenInstalling) var copyFileWhenInstalling

    let location: SoundFontKind
    if copyFileWhenInstalling {
      log.info("copying file to app folder")
      let destination = try copyToSharedFolder(
        &state,
        displayName: displayName,
        source: source,
        allowExisting: allowExisting
      )
      location = .installed(file: destination)
    } else {
      log.info("using external file")
      let bookmark = Bookmark(url: source, name: displayName)
      location = .external(bookmark: bookmark)
    }
    return location
  }

  private func copyToSharedFolder(
    _ state: inout State,
    displayName: String,
    source: URL,
    allowExisting: Bool
  ) throws -> URL {
    try source.withSecurityScopingThrows { url in
      log.info("copying \(url) to \(fileManager.sharedDocumentsDirectory())")
      let destination = fileManager.sharedDocumentsDirectory().appendingPathComponent(url.lastPathComponent)
      if allowExisting {
        try? fileManager.copyItem(source, destination)
      } else {
        try fileManager.copyItem(source, destination)
      }
      return destination
    }
  }

}

extension FileImporter.Destination.State: Equatable {}
extension FileImporter.Destination.Action: Equatable {}
extension FileImporter.Destination.State: _EphemeralState {
  public typealias Action = Alert
}
