// Copyright © 2025 Brad Howes. All rights reserved.

import AudioToolbox.AudioUnitProperties
import Foundation
import Sharing

/**
 Collection of attributes that define the active state of an SF2LibAU instance. There can be more than one instance of an SF2LibAU
 active at the same time in the same AUv3 host. The safest way to save and restore state is to rely on the values store in the
 ``AUAudioUnit/fullState`` attribute which would come from the AUv3 host when it loads a document.

 The state contains the unique IDs for the active soundfont, preset, and tag, and additional shared state values that affect the
 UI.
 */
public struct AUv3ActiveState: Codable {

  public enum Source: Codable {
    case app
    case auv3
  }

  public let source: Source
  public let soundFontId: SoundFont.ID
  public let presetId: Preset.ID
  public let tagId: Tag.ID

  public let activePresetGain: Double
  public let activePresetPan: Double
  public let fontsAndPresetsSplitPosition: Double
  public let fontsAndTagsSplitPosition: Double
  public let starFavoriteNames: Bool
  public let tagsListVisible: Bool

  public init(soundFontId: SoundFont.ID, presetId: Preset.ID, tagId: Tag.ID, source: Source = .auv3) {
    self.soundFontId = soundFontId
    self.presetId = presetId
    self.tagId = tagId
    self.source = source

    @Shared(.auv3ActivePresetGain) var activePresetGain
    @Shared(.auv3ActivePresetPan) var activePresetPan
    @Shared(.auv3FontsAndPresetsSplitPosition) var fontsAndPresetsSplitPosition
    @Shared(.auv3FontsAndTagsSplitPosition) var fontsAndTagsSplitPosition
    @Shared(.auv3StarFavoriteNames) var starFavoriteNames
    @Shared(.auv3TagsListVisible) var tagsListVisible

    self.activePresetGain = activePresetGain
    self.activePresetPan = activePresetPan
    self.fontsAndPresetsSplitPosition = fontsAndPresetsSplitPosition
    self.fontsAndTagsSplitPosition = fontsAndTagsSplitPosition
    self.starFavoriteNames = starFavoriteNames
    self.tagsListVisible = tagsListVisible
  }

  public func encode() throws -> Data { try JSONEncoder().encode(self) }

  public static func decode(data: Data) throws -> AUv3ActiveState {
    let activeState = try JSONDecoder().decode(AUv3ActiveState.self, from: data)

    @Shared(.auv3ActivePresetGain) var activePresetGain
    @Shared(.auv3ActivePresetPan) var activePresetPan
    @Shared(.auv3FontsAndPresetsSplitPosition) var fontsAndPresetsSplitPosition
    @Shared(.auv3FontsAndTagsSplitPosition) var fontsAndTagsSplitPosition
    @Shared(.auv3StarFavoriteNames) var starFavoriteNames
    @Shared(.auv3TagsListVisible) var tagsListVisible

    $activePresetGain.withLock { $0 = activePresetGain }
    $activePresetPan.withLock { $0 = activePresetPan }
    $fontsAndPresetsSplitPosition.withLock { $0 = fontsAndPresetsSplitPosition }
    $fontsAndTagsSplitPosition.withLock { $0 = fontsAndTagsSplitPosition }
    $starFavoriteNames.withLock { $0 = starFavoriteNames }
    $tagsListVisible.withLock { $0 = tagsListVisible }

    return activeState
  }
}

extension AUv3ActiveState: CustomStringConvertible {
  public var description: String {
    """
    <AUv3ActiveState soundFontId=\(soundFontId) presetId=\(presetId) tagId=\(tagId)/>
    """
  }
}

public struct FullState {
  public let state: [String: Any]

  public var activeState: AUv3ActiveState? {
    guard let data = state[kAUPresetDataKey] as? Data else { return nil }
    return try? AUv3ActiveState.decode(data: data)
  }

  public init(state: [String: Any]) {
    self.state = state
  }

  public init(activeState: AUv3ActiveState, base: [String: Any]? = nil) throws {
    let component = Bundle.main.audioComponentDescription
    var state = base ?? [:]
    state[kAUPresetDataKey] = try activeState.encode()
    state[kAUPresetTypeKey] = component.componentType
    state[kAUPresetSubtypeKey] = component.componentSubType
    state[kAUPresetManufacturerKey] = component.componentManufacturer
    state[kAUPresetVersionKey] = FourCharCode(67072)
    self.state = state
  }
}
