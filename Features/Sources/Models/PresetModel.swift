// Copyright © 2024 Brad Howes. All rights reserved.

import AVFoundation
import Foundation
import SwiftData


@Model
public final class PresetModel {
  public let soundFontId: String
  public let index: Int
  public var name: String
  public var visible: Bool = true

  @Relationship(deleteRule: .cascade) public let info: PresetInfoModel
  @Relationship(deleteRule: .cascade) public let audioSettings: AudioSettingsModel
  @Relationship(deleteRule: .cascade) public var favorites: [FavoriteModel] = []

  public init(soundFontId: String, index: Int, name: String, info: PresetInfoModel, audioSettings: AudioSettingsModel) {
    self.soundFontId = soundFontId
    self.index = index
    self.name = name
    self.info = info
    self.audioSettings = audioSettings
  }
}
