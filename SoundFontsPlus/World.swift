// Copyright © 2024 Brad Howes. All rights reserved.

import AVFoundation
import Foundation
import SwiftData


@Model
final class Tag {
  @Attribute(.unique) var name: String

  init(name: String) {
    self.name = name
  }
}

@Model
final class ReverbConfig {
  var enabled: Bool
  var preset: Int
  var wetDryMix: AUValue

  init(enabled: Bool, preset: Int, wetDryMix: AUValue) {
    self.enabled = enabled
    self.preset = preset
    self.wetDryMix = wetDryMix
  }
}

@Model
final class DelayConfig {
  var enabled: Bool
  var time: AUValue
  var feedback: AUValue
  var cutoff: AUValue
  var wetDryMix: AUValue

  init(enabled: Bool, time: AUValue, feedback: AUValue, cutoff: AUValue, wetDryMix: AUValue) {
    self.enabled = enabled
    self.time = time
    self.feedback = feedback
    self.cutoff = cutoff
    self.wetDryMix = wetDryMix
  }
}

@Model
final class Favorite {
  let preset: Preset
  var config: PresetConfig

  init(preset: Preset, config: PresetConfig) {
    self.preset = preset
    self.config = config
  }
}

@Model
final class PresetConfig {
  var name: String
  var keyboardLowestNote: Int?
  var keyboardLowestNoteEnabled: Bool = false
  var reverbConfig: ReverbConfig?
  var delayConfig: DelayConfig?
  var pitchBendRange: Int?
  var gain: Float = 0.0
  var pan: Float = 0.0
  var presetTuning: Float = 0.0
  var presetTranspose: Int?
  var notes: String?
  var isHidden: Bool?

  init(name: String) {
    self.name = name
  }
}

@Model
final class Preset {
  @Attribute(.unique) let index: Int
  let soundFont: SoundFont
  let originalName: String
  let bank: Int
  let program: Int
  // This configures the stock preset from the SoundFont
  var config: PresetConfig

  @Relationship(deleteRule: .cascade, inverse: \Favorite.preset)
  var favorites: [Favorite] = []

  init(index: Int, soundFont: SoundFont, originalName: String, bank: Int, program: Int, config: PresetConfig) {
    self.index = index
    self.soundFont = soundFont
    self.originalName = originalName
    self.bank = bank
    self.program = program
    self.config = config
  }
}

@Model
final class Location {

  enum Kind: String, Codable {
    case builtin
    case installed
    case bookmark
  }

  public let url: URL
  public let data: Data?
  public let kind: Kind

  init(url: URL, kind: Kind, data: Data?) {
    self.url = url
    self.kind = kind
    self.data = data
  }
}

@Model
final class SoundFont {
  @Attribute(.unique) let location: Location
  var name: String
  let originalDisplayName: String
  let embeddedName: String
  let embeddedComment: String
  let embeddedAuthor: String
  let embeddedCopyright: String
  var tags: [Tag] = []
  var visible: Bool = true

  init(location: Location, name: String, embeddedName: String, embeddedComment: String, embeddedAuthor: String,
       embeddedCopyright: String) {
    self.location = location
    self.name = name
    self.originalDisplayName = name
    self.embeddedName = embeddedName
    self.embeddedComment = embeddedComment
    self.embeddedAuthor = embeddedAuthor
    self.embeddedCopyright = embeddedCopyright
  }
}
