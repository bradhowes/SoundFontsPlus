import ComposableArchitecture
import Foundation
import Tagged
import Sharing

public struct ActiveState: Codable, Equatable, Sendable {

  public var activeSoundFontId: SoundFont.ID?
  public var selectedSoundFontId: SoundFont.ID?
  public var activePresetId: Preset.ID?
  public var activeTagId: Tag.ID?

  public init() {}
}

extension SharedKey where Self == InMemoryKey<ActiveState>.Default {
  public static var activeState: Self {
    Self[.inMemory("activeState"), default: .init()]
  }
}
