import ComposableArchitecture
import SwiftUI

extension AlertState where Action == FileImporterFeature.Destination.Alert {

  static func addedSummary(displayName: String) -> Self {
    Self {
      TextState("Added sound font \(displayName)")
    } actions: {
      ButtonState(role: .cancel) {
        TextState("OK")
      }
    }
  }

  static func genericFailureToImport(error: Error) -> Self {
    Self {
      TextState("Failed to add sound font: \(error.localizedDescription)")
    } actions: {
      ButtonState(role: .cancel) {
        TextState("OK")
      }
    }
  }

  static func invalidSoundFontFormat(displayName: String) -> Self {
    Self {
      TextState("'\(displayName)' is not a valid sound font file.")
    } actions: {
      ButtonState(role: .cancel) {
        TextState("OK")
      }
    }
  }

  static func continueWithDuplicateFile(url: URL) -> Self {
    Self {
      TextState("Duplicate file")
    } actions: {
      ButtonState(action: .continueWithDuplicateFile) {
        TextState("Continue")
      }
      ButtonState(role: .cancel) {
        TextState("Cancel")
      }
    } message: {
      let baseName = url.lastPathComponent
      return TextState(
      """
      The sound font file "\(baseName)" already exists on this device.
      You can continue to add it, but you may see duplicate values in the font list.
      """
      )
    }
  }
}
