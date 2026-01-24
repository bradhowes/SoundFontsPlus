// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import Models
import SwiftUI

extension AlertState {

  static func failedToPick(error: Error) -> Self {
    Self {
      TextState("Failed to Pick")
    } actions: {
      ButtonState(role: .cancel) {
        TextState("OK")
      }
    } message: {
      TextState("\(error.localizedDescription)")
    }
  }

  static func replaceDuplicateFile(action: Action, displayName: String) -> Self {
    Self {
      TextState("File Exists")
    } actions: {
      ButtonState(role: .destructive, action: action) { TextState("Overwrite") }
      ButtonState(role: .cancel) { TextState("Cancel") }
    } message: {
      TextState("Found existing file for \(displayName). Do you wish to replace it with the new one?")
    }
  }

  static public func importResults(summary: String) -> Self {
    Self {
      TextState("Finished Importing")
    } actions: {
      ButtonState(role: .cancel) { TextState("OK") }
    } message: {
      TextState(summary)
    }
  }
}
