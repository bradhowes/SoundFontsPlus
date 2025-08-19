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
    var showChooser: Bool = false
    var notice: String?
  }

  public enum Action {
    case destination(PresentationAction<Destination.Action>)
    case filePicked(Result<URL, Error>)
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

      case let .filePicked(result):
        state.showChooser = false
        return filePicked(&state, result: result)

      case .showFileImporter:
        state.showChooser = true
      }
      return .none
    }
  }
}

extension FileImporterFeature {

  private func filePicked(_ state: inout State, result: Result<URL, Error>) -> Effect<Action> {

    switch result {

    case .success(let url):
      let displayName = String(url.lastPathComponent.withoutExtension)
      return importFile(&state, displayName: displayName, url: url)

    case .failure(let error):
      state.destination = .alert(.failedToPick(error: error))
      return .none
    }
  }

  private func importFile(_ state: inout State, displayName: String, url: URL) -> Effect<Action> {
    if !validateSoundFont(url: url) {
      state.destination = .alert(.invalidSoundFontFormat(displayName: displayName))
      return .none
    }

    do {
      let kind = try placeSoundFont(displayName: displayName, url: url)
      try SoundFont.add(displayName: displayName, soundFontKind: kind)
    } catch CocoaError.fileWriteFileExists {
      state.destination = .alert(.continueWithDuplicateFile(url: url, action: .continueWithDuplicateFile))
    } catch {
      state.destination = .alert(.genericFailureToImport(displayName: displayName, error: error))
      return .none
    }

    state.destination = .alert(.addedSummary(displayName: displayName))
    return .none
  }

  private func validateSoundFont(url: URL) -> Bool {
    var fileInfo = SF2FileInfo(url.path(percentEncoded: false))
    return fileInfo.load()
  }

  private func placeSoundFont(displayName: String, url: URL) throws -> SoundFontKind {
    @Shared(.copyFileWhenInstalling) var copyFileWhenInstalling
    let location: SoundFontKind
    if copyFileWhenInstalling {
      location = .installed(file: try copyToSharedFolder(source: url))
    } else {
      location = .external(bookmark: Bookmark(url: url, name: displayName))
    }
    return location
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
