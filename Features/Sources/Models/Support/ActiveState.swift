import ComposableArchitecture
import Foundation
import Tagged
import Sharing

public struct ActiveState: Codable, Equatable, Sendable {

  public var activeSoundFontId: SoundFont.ID?
  public var selectedSoundFontId: SoundFont.ID?
  public var activePresetId: Preset.ID?
  public var activeTagId: Tag.ID?

  public init() {
    activeSoundFontId = .init(rawValue: 1)
    activePresetId = .init(rawValue: 1)
    activeTagId = Tag.Ubiquitous.all.id
  }
}

extension URL {
  static public let activeStateURL = FileManager.default.sharedDocumentsDirectory.appendingPathComponent("activeState.json")
}

extension SharedKey where Self == FileStorageKey<ActiveState>.Default {
  public static var activeState: Self {
    Self[.fileStorage(.activeStateURL), default: .init()]
  }
}
