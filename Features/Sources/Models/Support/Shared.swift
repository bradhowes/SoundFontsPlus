import ComposableArchitecture
import Foundation
import Tagged

public struct ActiveState: Codable, Equatable, Sendable {

  public private(set) var activeSoundFontKey: SoundFontModel.Key?
  public private(set) var selectedSoundFontKey: SoundFontModel.Key?
  public private(set) var activePresetKey: PresetModel.Key?
  public private(set) var activeTagKey: TagModel.Key?

  public init() {}

  public mutating func setActiveSoundFontKey(_ key: SoundFontModel.Key?) {
    activeSoundFontKey = key
  }

  public mutating func setSelectedSoundFontKey(_ key: SoundFontModel.Key?) {
    selectedSoundFontKey = key
  }

  public mutating func setActivePresetKey(_ key: PresetModel.Key?) {
    activePresetKey = key
  }

  public mutating func setActiveTagKey(_ key: TagModel.Key) {
    activeTagKey = key
  }
}

extension PersistenceReaderKey where Self == InMemoryKey<ActiveState> {
  public static var activeState: Self {
    inMemory("activeState")
  }
}

extension PersistenceReaderKey where Self == PersistenceKeyDefault<InMemoryKey<ActiveState>> {
  public static var activeState: Self { PersistenceKeyDefault(.activeState, .init()) }
}
