// Copyright © 2024 Brad Howes. All rights reserved.

import AVFoundation
import Foundation
import SwiftData


@Model
public final class FavoriteModel {
  @Attribute(.unique) public let id: String

  public let soundFont: SoundFontModel
  public let preset: PresetModel

  public var name: String
  public var notes: String?

  @Relationship(deleteRule: .cascade) public var audioSettings: AudioSettingsModel

  public init(id: UUID, soundFont: SoundFontModel, preset: PresetModel, name: String, 
              audioSettings: AudioSettingsModel) {
    self.id = id.uuidString
    self.soundFont = soundFont
    self.preset = preset
    self.name = name
    self.audioSettings = audioSettings
  }
}
