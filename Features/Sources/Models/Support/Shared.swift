import ComposableArchitecture
import Foundation
import Tagged
import Sharing

public struct ActiveState: Codable, Equatable, Sendable {

  public private(set) var activeSoundFontKey: SoundFont.ID?
  public private(set) var selectedSoundFontKey: SoundFont.ID?
  public private(set) var activePresetKey: Preset.ID?
  public private(set) var activeTagKey: Tag.ID?

  public init() {}

  public mutating func setActiveSoundFontKey(_ key: SoundFont.ID?) {
    activeSoundFontKey = key
  }

  public mutating func setSelectedSoundFontKey(_ key: SoundFont.ID?) {
    selectedSoundFontKey = key
  }

  public mutating func setActivePresetKey(_ key: Preset.ID?) {
    activePresetKey = key
  }

  public mutating func setActiveTagKey(_ key: Tag.ID) {
    activeTagKey = key
  }
}

extension SharedReaderKey where Self == InMemoryKey<ActiveState> {
  public static var activeState: Self {
    inMemory("activeState")
  }
}

//extension SharedReaderKey where Self == InMemoryKey<ActiveState>.Default {
//  public static var activeState: Self { SharedReaderKey(.activeState, .init()) }
//}
