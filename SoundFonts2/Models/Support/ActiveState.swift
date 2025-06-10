// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import Foundation
import Tagged
import Sharing

public struct ActiveState: Codable, Equatable, Sendable {

  public var activeSoundFontId: SoundFont.ID?
  public var selectedSoundFontId: SoundFont.ID?
  public var activePresetId: Preset.ID?
  public var activeTagId: FontTag.ID?

  public var presetSource: SoundFont.ID? { selectedSoundFontId ?? activeSoundFontId }

  public init() {
    activeSoundFontId = SoundFont.ID(rawValue: 1)
    activePresetId = Preset.ID(rawValue: 1)
    activeTagId = FontTag.Ubiquitous.all.id
    selectedSoundFontId = activeSoundFontId
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
