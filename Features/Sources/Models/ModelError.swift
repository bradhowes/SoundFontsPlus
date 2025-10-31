// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation

public enum ModelError: Error, Equatable {
  case duplicateTag(name: String)
  case renameUbiquitous(name: String)
  case emptyTagName
  case deleteUbiquitous(name: String)
  case failedToInsertSoundFont(name: String)
  case loadFailure(url: URL)
  case dataIsNotValidURL(data: Data, displayName: String)
  case urlIsNotValidData(url: URL)
}

extension ModelError: CustomStringConvertible {
  public var description: String {
    switch self {
    case .duplicateTag(name: let name):
      return "Tag '\(name)' already exists."
    case .renameUbiquitous(name: let name):
      return "Cannot change the name of built-in tag '\(name)'."
    case .emptyTagName:
      return "Tag name cannot be empty."
    case .deleteUbiquitous(name: let name):
      return "Cannot delete built-in tag \(name)."
    case .failedToInsertSoundFont(name: let name):
      return "Failed to add SoundFont \(name) to database -- internal database conflict."
    case .loadFailure(url: let url):
      return "Failed to load SF2 '\(url.lastPathComponent)' due to corrupt or missing file. Try deleting and adding back."
    case let .dataIsNotValidURL(_, displayName):
      return "Location value for SF2 '\(displayName) is corrupted. Unable to load."
    case .urlIsNotValidData(url: let url):
      return "Internal error - invalid URL '\(url)'. Unable to save to database."
    }
  }
}
