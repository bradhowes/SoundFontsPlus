// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import Foundation
import Sharing

// MARK: - AppStorage Bool settings

extension SharedKey where Self == AppStorageKey<Bool>.Default {
  public static var backgroundProcessing: Self { Self[.appStorage("backgroundProcessing"), default: true] }
  public static var duckOtherApps: Self { Self[.appStorage("duckOtherApps"), default: false] }
  public static var mixWithOtherApps: Self { Self[.appStorage("mixWithOtherApps"), default: true] }
  public static var playSoundOnPresetChange: Self { Self[.appStorage("playSoundOnPresetChange"), default: true] }
}

// MARK: - AppStorage KeyLabels settings

extension SharedKey where Self == AppStorageKey<KeyLabels>.Default {
  public static var keyLabels: Self { Self[.appStorage("keyLabels"), default: .cOnly] }
}

// MARK: - AppStorage Note settings

extension SharedKey where Self == AppStorageKey<Note>.Default {
  public static var firstVisibleKey: Self { Self[.appStorage("firstVisibleKey"), default: .C4] }
}

// MARK: - InMemory Bool settings (AUv3)

extension SharedKey where Self == InMemoryKey<Bool>.Default {
  public static var auv3ShowOnlyFavorites: Self { Self[.inMemory(.auv3ShowOnlyFavorites), default: false] }
  public static var auv3StarFavoriteNames: Self { Self[.inMemory(.auv3StarFavoriteNames), default: true] }
  public static var auv3TagsListVisible: Self { Self[.inMemory(.auv3TagsListVisible), default: false] }
  public static var isAUv3: Self { Self[.inMemory("isAUv3"), default: false] }
}

// MARK: - InMemory Double settings (AUv3)

extension SharedKey where Self == InMemoryKey<Double>.Default {
  public static var auv3ActivePresetGain: Self { Self[.inMemory(.auv3ActivePresetGain), default: 1.0] }
  public static var auv3ActivePresetPan: Self { Self[.inMemory(.auv3ActivePresetPan), default: 0.0] }
  public static var auv3FontsAndPresetsSplitPosition: Self { Self[.inMemory(.auv3FontsAndPresetsSplitPosition), default: 0.5] }
  public static var auv3FontsAndTagsSplitPosition: Self { Self[.inMemory(.auv3FontsAndTagsSplitPosition), default: 0.4] }
}

// MARK: Tags for AUv3 state elements

extension String {
  public static let auv3ActivePresetGain = "auv3ActivePresetGain"
  public static let auv3ActivePresetPan = "auv3ActivePresetPan"
  public static let auv3FontsAndPresetsSplitPosition = "auv3FontsAndPresetsSplitPosition"
  public static let auv3FontsAndTagsSplitPosition = "auv3FontsAndTagsSplitPosition"
  public static let auv3ShowOnlyFavorites = "auv3ShowOnlyFavorites"
  public static let auv3StarFavoriteNames = "auv3StarFavoriteNames"
  public static let auv3TagsListVisible = "auv3TagsListVisible"
}
