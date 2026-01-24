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
