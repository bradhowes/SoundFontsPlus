// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import Models
import SwiftUI

extension AlertState {

  static func addedSummary(displayName: String) -> Self {
    Self {
      TextState("Added")
    } actions: {
      ButtonState(role: .cancel) {
        TextState("OK")
      }
    } message: {
      TextState("Successfully addeed sound font '\(displayName)'.")
    }
  }

  static func fileAlreadyImported(url: URL) -> Self {
    Self {
      TextState("Already Imported")
    } actions: {
      ButtonState(role: .cancel) {
        TextState("OK")
      }
    } message: {
      let baseName = url.lastPathComponent
      return TextState(
      """
      The file "\(baseName)" already exists in the collection.
      """
      )
    }
  }

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

  static func genericFailureToImport(displayName: String, error: Error) -> Self {
    Self {
      TextState("Failed to Add")
    } actions: {
      ButtonState(role: .cancel) {
        TextState("OK")
      }
    } message: {
      TextState("\(error.localizedDescription)")
    }
  }

  static func invalidSoundFontFormat(displayName: String) -> Self {
    Self {
      TextState("Invalid SF2 File")
    } actions: {
      ButtonState(role: .cancel) {
        TextState("OK")
      }
    } message: {
      TextState("'\(displayName)' does not appear to be a valid sound font file.")
    }
  }
}
