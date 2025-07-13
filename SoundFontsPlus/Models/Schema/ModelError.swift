// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation

public enum ModelError: Error, Equatable {
  case duplicateTag(name: String)
  case renameUbiquitous(name: String)
  case emptyTagName
  case deleteUbiquitous(name: String?)
  case failedToSave(name: String)
  case failedToFetch(key: String)
  case failedToFetchAny
  case loadFailure(name: String)
  case invalidLocation(name: String)
  case invalidBookmark(name: String)
  case taggingUbiquitous
  case untaggingUbiquitous
  case alreadyTagged
  case notTagged
  case dataIsNotValidURL(data: Data)
  case urlIsNotValidData(url: URL)
}
