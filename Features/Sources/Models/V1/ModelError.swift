import Foundation

public enum ModelError: Error {
  case duplicateTag(name: String)
  case deleteUbiquitous(name: String)
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
