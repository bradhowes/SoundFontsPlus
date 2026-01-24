// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture

// MARK: - App alerts

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
Deleting a SoundFont will delete any customizations you may have made to its presets. This cannot be undone.
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
Deleting sound fonts will delete any customizations you may have made to their presets. This cannot be undone.
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

  static public func invalidBookmark(displayName: String) -> Self {
    Self {
      TextState("Invalid Bookmark for '\(displayName)'")
    } actions: {
      ButtonState(role: .cancel) { TextState("OK") }
    } message: {
      TextState(
"""
Unable to resolve the bookmark for the sound font '\(displayName)' due to an internal error. \
Please delete the sound font and then add it back.
"""
      )
    }
  }

  static public func missingFile(displayName: String) -> Self {
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
This tag is associated with \(associationCount) sound fonts — they will not be affected. \
Deleting the tag cannot be undone.
"""
      )
    }
  }

  static public func tagWillBeHidden(displayName: String) -> Self {
    Self {
      TextState("Empty Tags are Hidden")
    } actions: {
      ButtonState(role: .cancel) { TextState("OK") }
    } message: {
      TextState(
"""
Due to the "Hide tags with no fonts" setting, the '\(displayName)' tag will not appear in the main tag view since it is not \
associated with any sound fonts.
"""
      )
    }
  }
}
