// Copyright © 2025 Brad Howes. All rights reserved.

import BaseSupport
import ComposableArchitecture
import Engine
import Models
import SwiftUI
import UniformTypeIdentifiers

private let log = Logger(category: "FileImporterFeature")

@Reducer
public struct FileImporter {

  @Reducer(state: .equatable, action: .equatable)
  public enum Destination: Equatable {
    case alert(AlertState<Alert>)

    @CasePathable
    public enum Alert {
      case importDuplicateFileConfirmed
    }
  }

  @ObservableState
  public struct State: Equatable {
    let types = ["com.braysoftware.sf2", "com.soundblaster.soundfont"].compactMap { UTType($0) }
    var showChooser: Bool = false
    @Presents var destination: Destination.State?

    public init() {}
  }

  public enum Action {
    case destination(PresentationAction<Destination.Action>)
    case filePickerCancelled
    case filePicked(Result<URL, Error>)
    case showFileImporter
  }

  public init() {}

  @Dependency(\.fileManager) var fileManager
  @Dependency(\.dismiss) var dismiss

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {

      case .filePickerCancelled:
        state.showChooser = false
        return .none

      case .destination(.presented(.alert(.importDuplicateFileConfirmed))):
        return .none

      case .destination:
        return .none

      case let .filePicked(result):
        state.showChooser = false
        return filePicked(&state, result: result)

      case .showFileImporter:
        state.showChooser = true
        return .none
      }
    }
    .ifLet(\.destination, action: \.destination)
  }
}

// extension Result<URL, Error>: Equatable {}

extension FileImporter.Destination.State: _EphemeralState {
  public typealias Action = Alert
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

  private func importFile(_ state: inout State, displayName: String, url: URL) -> Effect<Action> {
    do {
      guard let kind = try placeSoundFont(&state, displayName: displayName, source: url) else {
        return .none
      }
      try SoundFont.add(displayName: displayName, soundFontKind: kind)
    } catch CocoaError.fileWriteFileExists {
      state.destination = .alert(.continueWithDuplicateFile(url: url, action: .importDuplicateFileConfirmed))
    } catch {
      state.destination = .alert(.genericFailureToImport(displayName: displayName, error: error))
      return .none
    }

    state.destination = .alert(.addedSummary(displayName: displayName))
    return .none
  }

  private func validateSoundFont(url: URL) -> Bool {
    let accessing = url.startAccessingSecurityScopedResource()
    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
    var fileInfo = SF2FileInfo(std.string(url.path(percentEncoded: false)))
    return fileInfo.load()
  }

  private func placeSoundFont(_ state: inout State, displayName: String, source: URL) throws -> SoundFontKind? {
    @Shared(.copyFileWhenInstalling) var copyFileWhenInstalling
    let location: SoundFontKind
    if copyFileWhenInstalling {
      log.info("copying file to app folder")
      guard let destination = try copyToSharedFolder(&state, displayName: displayName, source: source) else {
        log.info("copying failed")
        return nil
      }

      if !validateSoundFont(url: destination) {
        log.info("invalid SF2 file")
        state.destination = .alert(.invalidSoundFontFormat(displayName: displayName))
        return nil
      }

      location = .installed(file: destination)
    } else {
      log.info("using external file")
      if !validateSoundFont(url: source) {
        log.info("invalid SF2 file")
        state.destination = .alert(.invalidSoundFontFormat(displayName: displayName))
        return nil
      }

      let bookmark = Bookmark(url: source, name: displayName)
      location = .external(bookmark: bookmark)
    }
    return location
  }

  private func copyToSharedFolder(_ state: inout State, displayName: String, source: URL) throws -> URL? {
    let accessing = source.startAccessingSecurityScopedResource()
    defer { if accessing { source.stopAccessingSecurityScopedResource() } }

    let destination = fileManager.sharedDocumentsDirectory().appendingPathComponent(source.lastPathComponent)
    try fileManager.copyItem(source, destination)

    return destination
  }
}
