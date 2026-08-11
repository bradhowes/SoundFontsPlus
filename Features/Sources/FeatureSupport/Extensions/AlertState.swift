// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture

// MARK: - Settings alerts

extension AlertState {

  static public func confirmDisableCopyFile(action: Action) -> Self {
    Self {
      TextState("Disable Copying?")
    } actions: {
      ButtonState(action: action) {
        TextState("Yes")
      }
      ButtonState(role: .cancel) {
        TextState("Cancel")
      }
    } message: {
      TextState(
"""
Not copying files may lead to unusable sound fonts if the file moves or is not immediately available on the device.
"""
      )
    }
  }

  static public func confirmDisableIdleTimer(action: Action) -> Self {
    Self {
      TextState("Disable Device Locking?")
    } actions: {
      ButtonState(action: action) {
        TextState("Yes")
      }
      ButtonState(role: .cancel) {
        TextState("Cancel")
      }
    } message: {
      TextState(
"""
Disabling will prevent the device from sleeping and locking the screen, resulting in increased battery usage \
and reduced security when unattended.
"""
      )
    }
  }
}

// MARK: - Preset alerts

extension AlertState {

  static public func confirmHidePreset(action: Action, displayName: String) -> Self {
    Self {
      TextState("Hide '\(displayName)'?")
    } actions: {
      ButtonState(action: action) { TextState("Hide") }
      ButtonState(role: .cancel) { TextState("Cancel") }
    } message: {
      TextState(
"""
Hiding a preset will keep it from appearing in the list of presets. \
You can restore visibility via the preset visibility button in the toolbar.
"""
      )
    }
  }

  static public func confirmDeleteFavorite(action: Action, displayName: String) -> Self {
    Self {
      TextState("Delete '\(displayName)'?")
    } actions: {
      ButtonState(role: .destructive, action: action) { TextState("Delete") }
      ButtonState(role: .cancel) { TextState("Cancel") }
    } message: {
      TextState(
"""
Deleting a favorite cannot be undone.
"""
      )
    }
  }
}

// MARK: - SoundFontsList alerts

extension AlertState {

  static public func confirmDeleteSoundFont(action: Action, displayName: String) -> Self {
    Self {
      TextState("Delete '\(displayName)'?")
    } actions: {
      ButtonState(role: .destructive, action: action) { TextState("Delete") }
      ButtonState(role: .cancel) { TextState("Cancel") }
    } message: {
      TextState(
"""
Deleting a SoundFont will delete any customizations you may have made to its presets.

This cannot be undone.
"""
      )
    }
  }

  static public func confirmDeleteSoundFontCollection(action: Action, count: Int) -> Self {
    Self {
      TextState("Delete ^[\(count) sound font](inflect: true)?")
    } actions: {
      ButtonState(role: .destructive, action: action) { TextState("Delete") }
      ButtonState(role: .cancel) { TextState("Cancel") }
    } message: {
      TextState(
"""
Deleting sound fonts will delete any customizations you may have made to their presets.

This cannot be undone.
"""
      )
    }
  }

  static public func genericDeleteFailure(_ message: String) -> Self {
    Self {
      TextState("Failed to Delete")
    } actions: {
      ButtonState(role: .cancel) { TextState("OK") }
    } message: {
      TextState(message)
    }
  }

  static public func invalidBookmark(action: Action, displayName: String) -> Self {
    Self {
      TextState("Invalid Bookmark for '\(displayName)'")
    } actions: {
      ButtonState(role: .cancel) { TextState("Ignore") }
      ButtonState(role: .destructive, action: action) { TextState("Delete") }
    } message: {
      TextState(
"""
Unable to resolve the bookmark for the sound font '\(displayName)'. It may have been deleted.
"""
      )
    }
  }

  static public func missingExternalFile(displayName: String) -> Self {
    Self {
      TextState("Missing File for '\(displayName)'")
    } actions: {
      ButtonState(role: .cancel) { TextState("OK") }
    } message: {
      TextState(
"""
Unable to locate the external file for sound font '\(displayName)'. \
Connect the external drive containing the file to resolve this issue.
"""
      )
    }
  }

  static public func missingFileForSelectedPreset(action: Action, displayName: String) -> Self {
    Self {
      TextState("File for '\(displayName)' Missing")
    } actions: {
      ButtonState(role: .destructive, action: action) { TextState("Remove") }
      ButtonState(role: .cancel) { TextState("Cancel") }
    } message: {
      TextState(
"""
Unable to locate the file for sound font '\(displayName)'. Do you wish to \
remove the sound font entry for it?
"""
      )
    }
  }
}

// MARK: - SoundFontEditor alerts

extension AlertState {

  static public func confirmShowHiddenPresets(action: Action) -> Self {
    Self {
      TextState("Unhide Presets?")
    } actions: {
      ButtonState(action: action) {
        TextState("Yes")
      }
      ButtonState(role: .cancel) {
        TextState("Cancel")
      }
    } message: {
      TextState(
"""
Confirm to immediately unhide all of the hidden presets.
"""
      )
    }
  }
}

// MARK: - TagsEditor alerts

extension AlertState {

  static public func confirmDeleteTag(action: Action, displayName: String, associationCount: Int) -> Self {
    Self {
      TextState("Delete '\(displayName)'?")
    } actions: {
      ButtonState(role: .destructive, action: action) { TextState("Delete") }
      ButtonState(role: .cancel) { TextState("Cancel") }
    } message: {
      TextState(
"""
This tag is associated with \(associationCount) sound fonts — they will not be affected.

Deleting the tag cannot be undone.
"""
      )
    }
  }

  static public func newTagsHidden(disableAlert: Action, disableOption: Action) -> Self {
    Self {
      TextState("Hidden Tags")
    } actions: {
      ButtonState(role: .cancel) { TextState("OK") }
      ButtonState(action: disableOption) { TextState("Show Hidden Tags") }
      ButtonState(action: disableAlert) { TextState("Disable Alert") }
    } message: {
      TextState(
"""
Due to the "Hide tags with no sound fonts" setting, one or more tags will not appear in the tags list. \
They will appear once associated with a sound font or when the setting is cleared.

Tap "Show Hidden Tags" to clear the setting.
Tap "Disable Alert" to stop showing this alert.
"""
      )
    }
  }
}

extension AlertState {

  public static func confirmReinitialize(action: Action) -> Self {
    Self {
      TextState("Reinitialize?")
    } actions: {
      ButtonState(role: .cancel) { TextState("Cancel") }
      ButtonState(role: .destructive, action: action) { TextState("Confirm") }
    } message: {
      TextState(
"""
Reinitializing will delete any changes made since you first installed the app. It will also remove \
any font files installed on the device, leaving only the four original sound fonts.

This action cannot be undone.
"""
      )
    }
  }

  public static func reinitialized() -> Self {
    Self {
      TextState("Reinitialized")
    } actions: {
      ButtonState(role: .none) { TextState("OK") }
    } message: {
      TextState(
"""
All customizations have been removed.
"""
      )
    }
  }
}

extension AlertState {

  public static func failedToPick(error: any Error) -> Self {
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

  public static func replaceDuplicateFile(action: Action, displayName: String) -> Self {
    Self {
      TextState("File Exists")
    } actions: {
      ButtonState(role: .destructive, action: action) { TextState("Overwrite") }
      ButtonState(role: .cancel) { TextState("Cancel") }
    } message: {
      TextState("Found existing file for \(displayName). Do you wish to replace it with the new one?")
    }
  }

  public static func importResults(summary: String) -> Self {
    Self {
      TextState("Finished Importing")
    } actions: {
      ButtonState(role: .cancel) { TextState("OK") }
    } message: {
      TextState(summary)
    }
  }

  public static func confirmMultipleImports(action: Action, count: Int) -> Self {
    Self {
      TextState("Import multiple font files?")
    } actions: {
      ButtonState(role: .none, action: action) { TextState("Continue") }
      ButtonState(role: .cancel) { TextState("Cancel") }
    } message: {
      TextState("Preparing to import \(count) sound font files.")
    }

  }
}
