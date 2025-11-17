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

  static public func confirmAddExisting(action: Action, displayName: String) -> Self {
    Self {
      TextState("Add '\(displayName)'?")
    } actions: {
      ButtonState(action: action) { TextState("Yes") }
      ButtonState(role: .cancel) { TextState("Cancel") }
    } message: {
      TextState(
"""
The SF2 file for \(displayName) exists on the device, but its presets do not appear in the database.
Do you wish to recreate entries in the database for it?
"""
      )
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
