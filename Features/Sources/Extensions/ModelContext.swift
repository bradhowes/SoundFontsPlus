// Copyright © 2024 Brad Howes. All rights reserved.

import Foundation
import SwiftData


public extension ModelContext {

  /**
   Combination of `registeredModel` and `fetch` for a specific `PersistentIdentifier` value.

   - parameter id: the ID to search for
   - returns: the found model instance of type `T` with the given ID or nil if not found
   */
  @MainActor
  func findExact<T: PersistentModel>(id: PersistentIdentifier) -> T? {

    // Handle the (common?) case where the model is known to the modelContext.
    if let exact: T = registeredModel(for: id) {
      return exact
    }

    // Search for the exact model via its unique `persistentModelID` value.
    let fetchDescriptor: FetchDescriptor<T> = .init(predicate: #Predicate { $0.persistentModelID == id })
    guard
      let result = try? fetch(fetchDescriptor),
      !result.isEmpty
    else {
      return nil
    }
    return result[0]
  }
}
