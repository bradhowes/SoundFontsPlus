// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import Engine
import SwiftUI
import UniformTypeIdentifiers

@Reducer
public struct FileImporterFeature {

  enum Failure: Error {
    case duplicateFile(displayName: String, url: URL)
    case invalidSoundFontFormat(displayName: String, url: URL)
    case sqlFailure(displayName: String, url: URL, error: Error)
    case fileManagerFailure(displayName: String, url: URL, error: CocoaError)
  }

  @Reducer(state: .equatable)
  public enum Destination: Equatable {
    case alert(AlertState<Alert>)

    @CasePathable
    public enum Alert {
      case addedSummary
      case continueWithDuplicateFile
      case genericFailureToImport
    }
  }

  @ObservableState
  public struct State: Equatable {
    @Presents var destination: Destination.State?
    let types = ["com.braysoftware.sf2", "com.soundblaster.soundfont"].compactMap { UTType($0) }
    var startImporting: Bool = false
    var notice: String?
  }

  public enum Action {
    case destination(PresentationAction<Destination.Action>)
    case finishedImportingFile(Result<URL, Error>)
    case showFileImporter
  }

  @Dependency(\.dismiss) var dismiss

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {

      case .destination(.presented(.alert)):
        return .none

      case .destination:
        return .none

      case let .finishedImportingFile(result):
        state.startImporting = false
        return finishedImportingFile(&state, result: result)

      case .showFileImporter:
        state.startImporting = true
      }
      return .none
    }
  }
}

extension FileImporterFeature {

  private func finishedImportingFile(_ state: inout State, result: Result<URL, Error>) -> Effect<Action> {
    switch result {
    case .success(let url):
      let displayName = String(url.lastPathComponent.withoutExtension)

      if !validateSoundFont(url: url) {
        state.destination = .alert(.invalidSoundFontFormat(displayName: displayName))
        return .none
      }

      do {
        try addSoundFont(url: url, copyFileWhenAdding: true)
        state.destination = .alert(.addedSummary(displayName: displayName))
      } catch CocoaError.fileWriteFileExists {
        state.destination = .alert(.continueWithDuplicateFile(url: url))
      } catch {
        state.destination = .alert(.genericFailureToImport(error: error))
      }
    case .failure(let error):
      state.destination = .alert(.genericFailureToImport(error: error))
    }

    return .none
  }

  private func validateSoundFont(url: URL) -> Bool {
    // Attempt to load the file to see if there are any errors
    var fileInfo = SF2FileInfo(url.path(percentEncoded: false))
    return fileInfo.load()
  }

  private func installSoundFont(displayName: String, url: URL) throws -> SoundFontKind {
    @Shared(.copyFileWhenInstalling) var copyFileWhenInstalling
    let location: SoundFontKind
    if copyFileWhenInstalling {
      location = .installed(file: try copyToSharedFolder(source: url))
    } else {
      location = .external(bookmark: Bookmark(url: url, name: displayName))
    }
    return location
  }

  private func addSoundFont(url: URL, copyFileWhenAdding: Bool) throws {
    // Use the file name for the initial display name. Users can change to other embedded values via editor.
    let displayName = String(url.lastPathComponent.withoutExtension)
    let location: SoundFontKind
    if copyFileWhenAdding {
      location = .installed(file: try copyToSharedFolder(source: url))
    } else {
      location = .external(bookmark: Bookmark(url: url, name: displayName))
    }

    try SoundFont.add(displayName: displayName, soundFontKind: location)
  }

  private func copyToSharedFolder(source: URL) throws -> URL {
    let accessing = source.startAccessingSecurityScopedResource()
    defer { if accessing { source.stopAccessingSecurityScopedResource() } }

    let destination = FileManager.default.sharedPath(for: source.lastPathComponent)
    try FileManager.default.copyItem(at: source, to: destination)

    return destination
  }
}

private extension String {
  var withoutExtension: Substring { self[self.startIndex..<(self.lastIndex(of: ".") ?? self.endIndex)] }
}
