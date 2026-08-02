// Copyright © 2026 Brad Howes. All rights reserved.

import AudioToolbox.AudioUnitProperties
import BaseSupport
import DependenciesTestSupport
import Sharing
import SQLiteData
import Tagged
import TestSupport
import Testing

@testable import Models

@Suite(
  .dependencies {
    $0.defaultDatabase = TestSupport.testDatabase()
  }
)
struct AUv3ActiveStateTests {

  @Test(arguments: [
    (1.0, 0.0, true, false, 0.5, 0.4),
    (0.7, -0.2, false, true, 0.3, 0.5)
  ])
  // swiftlint:disable:next function_parameter_count
  func construction(
    _ gain: Double,
    _ pan: Double,
    _ starFavoriteNames: Bool,
    _ tagsListVisible: Bool,
    _ fontsAndPresetsSplitPosition: Double,
    _ fontsAndTagsSplitPosition: Double
  ) throws {
    @Shared(.auv3ActivePresetGain) var activePresetGain = gain
    @Shared(.auv3ActivePresetPan) var activePresetPan = pan
    @Shared(.auv3FontsAndPresetsSplitPosition) var fapsp = fontsAndPresetsSplitPosition
    @Shared(.auv3FontsAndTagsSplitPosition) var fatsp = fontsAndTagsSplitPosition
    @Shared(.auv3StarFavoriteNames) var sfn = starFavoriteNames
    @Shared(.auv3TagsListVisible) var tlv = tagsListVisible

    let value = AUv3ActiveState(soundFontName: "Font 1", presetIndex: 1, tagName: Tag.Ubiquitous.all.displayName!)
    #expect(value.soundFontName == "Font 1")
    #expect(value.presetIndex == 1)
    #expect(value.tagName == "All")

    #expect(value.activePresetGain == gain)
    #expect(value.activePresetPan == pan)
    #expect(value.starFavoriteNames == starFavoriteNames)
    #expect(value.tagsListVisible == tagsListVisible)

    #expect(value.fontsAndPresetsSplitPosition == fontsAndPresetsSplitPosition)
    #expect(value.fontsAndTagsSplitPosition == fontsAndTagsSplitPosition)
  }

  @Test(arguments: [
    (1.0, 0.0, true, false, 0.5, 0.4),
    (0.7, -0.2, false, true, 0.3, 0.5)
  ])
  // swiftlint:disable:next function_parameter_count
  func encodeDecode(
    _ gain: Double,
    _ pan: Double,
    _ starFavoriteNames: Bool,
    _ tagsListVisible: Bool,
    _ fontsAndPresetsSplitPosition: Double,
    _ fontsAndTagsSplitPosition: Double
  ) throws {
    @Shared(.auv3ActivePresetGain) var activePresetGain = gain
    @Shared(.auv3ActivePresetPan) var activePresetPan = pan
    @Shared(.auv3FontsAndPresetsSplitPosition) var fapsp = fontsAndPresetsSplitPosition
    @Shared(.auv3FontsAndTagsSplitPosition) var fatsp = fontsAndTagsSplitPosition
    @Shared(.auv3StarFavoriteNames) var sfn = starFavoriteNames
    @Shared(.auv3TagsListVisible) var tlv = tagsListVisible

    let value = AUv3ActiveState(soundFontName: "Font 1", presetIndex: 1, tagName: Tag.Ubiquitous.all.displayName!)
    let encoded = try value.encode()
    let decoded = try AUv3ActiveState.decode(data: encoded)

    #expect(decoded.soundFontName == "Font 1")
    #expect(decoded.presetIndex == 1)
    #expect(decoded.tagName == "All")

    #expect(decoded.activePresetGain == gain)
    #expect(decoded.activePresetPan == pan)
    #expect(decoded.starFavoriteNames == starFavoriteNames)
    #expect(decoded.tagsListVisible == tagsListVisible)

    #expect(decoded.fontsAndPresetsSplitPosition == fontsAndPresetsSplitPosition)
    #expect(decoded.fontsAndTagsSplitPosition == fontsAndTagsSplitPosition)
  }

  @Test
  func presetLoadingInfo() throws {
    let value = AUv3ActiveState(soundFontName: "Original Font 1", presetIndex: 1, tagName: Tag.Ubiquitous.all.displayName!)
    let pli = value.presetLoadingInfo
    #expect(pli != nil)
  }

  @Test
  func description() throws {
    let value = AUv3ActiveState(soundFontName: "Original Font 1", presetIndex: 1, tagName: Tag.Ubiquitous.all.displayName!)
    #expect(value.description == "<AUv3ActiveState soundFontName=\"Original Font 1\" presetIndex=1 tagName=\"All\"/>")
  }

  @Test
  func fullState() throws {
    let value = AUv3ActiveState(soundFontName: "Font 1", presetIndex: 1, tagName: Tag.Ubiquitous.all.displayName!)
    let fullState = try FullState(activeState: value)
    let component = Bundle.main.audioComponentDescription
    #expect(fullState.state[kAUPresetDataKey] != nil)
    #expect(fullState.state[kAUPresetTypeKey] as? OSType == component.componentType)
    #expect(fullState.state[kAUPresetSubtypeKey] as? OSType == component.componentSubType)
    #expect(fullState.state[kAUPresetManufacturerKey] as? OSType == component.componentManufacturer)
    #expect(fullState.state[kAUPresetVersionKey] as? OSType == FourCharCode(67072))
  }

  @Test
  func fullStateRoundTrip() throws {
    let value = AUv3ActiveState(soundFontName: "Font 1", presetIndex: 1, tagName: Tag.Ubiquitous.all.displayName!)
    let fullState = try FullState(activeState: value)
    let rt = fullState.activeState
    #expect(rt != nil)
    #expect(rt == value)
  }

  @Test
  func fullStateEmpty() throws {
    let fullState = FullState(state: [:])
    let rt = fullState.activeState
    #expect(rt == nil)
  }
}
