// Copyright © 2025 Brad Howes. All rights reserved.

/**
 At any one time, there is only one active sound font ID in the system for presentation purposes: an active one that is the
 sound font containing the active preset, and a selected one that is showing the potential presets to be activated if selected.
 */
public enum PresetSource: Codable, Equatable, Sendable {
  case active(SoundFont.ID)
  case selected(SoundFont.ID)

  public static func makeActive(_ soundFontId: SoundFont.ID?) -> PresetSource? {
    guard let soundFontId else { return nil }
    return .active(soundFontId)
  }

  public var isActive: Bool {
    guard case .active = self else { return false }
    return true
  }

  public var isSelected: Bool { !isActive }
  public var activated: PresetSource { .active(id) }

  public var id: SoundFont.ID {
    switch self {
    case .active(let soundFontId): return soundFontId
    case .selected(let soundFontId): return soundFontId
    }
  }
}
