import ComposableArchitecture
import Foundation
import Tagged
import Sharing

public struct ActiveState: Codable, Equatable, Sendable {

  public private(set) var activeSoundFontId: SoundFont.ID?
  public private(set) var selectedSoundFontId: SoundFont.ID?
  public private(set) var activePresetId: Preset.ID?
  public private(set) var activeTagId: Tag.ID?

  public init() {}

  public mutating func setActiveSoundFontId(_ id: SoundFont.ID?) {
    activeSoundFontId = id
  }

  public mutating func setSelectedSoundFontId(_ id: SoundFont.ID?) {
    selectedSoundFontId = id
  }

  public mutating func setActivePresetId(_ id: Preset.ID?) {
    activePresetId = id
  }

  public mutating func setActiveTagId(_ id: Tag.ID) {
    activeTagId = id
  }
}

extension SharedKey where Self == InMemoryKey<ActiveState>.Default {
  public static var activeState: Self {
    Self[.inMemory("activeState"), default: .init()]
  }
}
