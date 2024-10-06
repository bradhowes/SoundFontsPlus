
public enum ModelError: Error {
  /// Thrown if attempting to create a tag with the same name as an existing one.
  case duplicateTag(name: String)
  case failedToSave(name: String)
  case failedToFetch(name: String)
  case failedToFetchAny
}

