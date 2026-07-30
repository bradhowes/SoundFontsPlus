// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import Models
import MorkAndMIDI
import Sharing
import Tagged

// MARK: - AppStorage Bool settings

extension SharedKey where Self == AppStorageKey<Bool>.Default {
  public static var confirmPresetHiding: Self { Self[.appStorage("stopConfirmingPresetHiding"), default: true] }
  public static var copyFileWhenInstalling: Self { Self[.appStorage("copyFileWhenInstalling"), default: true] }
  public static var delayLockEnabled: Self { Self[.appStorage("delayLockEnabled"), default: false] }
  public static var disableIdleTimer: Self { Self[.appStorage("disableIdleTimer"), default: false]}
  public static var disableNewTagIsHiddenAlert: Self { self[.appStorage("disableNewTagIsHiddenAlert"), default: false] }
  public static var effectsPanelVisible: Self { Self[.appStorage("effectsPanelVisible"), default: false] }
  public static var keyboardSlides: Self { Self[.appStorage("keyboardSlides"), default: false] }
  public static var midiAutoConnect: Self { Self[.appStorage("midiAutoConnect"), default: true] }
  public static var reverbLockEnabled: Self { Self[.appStorage("reverbLockEnabled"), default: false] }
  public static var showKeyNotes: Self { Self[.appStorage("showKeyNotes"), default: true] }
  public static var showActiveVoiceCount: Self { Self[.appStorage("showActiveVoiceCount"), default: true] }
  public static var showMIDINotesOnKeyboard: Self { Self[.appStorage("showMIDINotesOnKeyboard"), default: true] }
  public static var showMIDITrafficIndicator: Self { Self[.appStorage("showMIDITrafficIndicator"), default: true] }
  public static var showPresetIndexView: Self { Self[.appStorage("showPresetIndexView"), default: true] }
  public static var showSolfegeTags: Self { Self[.appStorage("showSolfegeTags"), default: false] }
  public static var starFavoriteNames: Self { Self[.appStorage("starFavoriteNames"), default: true] }
  public static var tagsListVisible: Self { Self[.appStorage("tagsListVisible"), default: false] }
}

// MARK: - AppStorage Double settings

extension SharedKey where Self == AppStorageKey<Double>.Default {
  public static var fontsAndPresetsSplitPosition: Self { Self[.appStorage("fontsAndPresetsSplitPosition"), default: 0.5] }
  public static var fontsAndTagsSplitPosition: Self { Self[.appStorage("fontsAndTagsSplitPosition"), default: 0.4] }
  public static var keyWidth: Self { Self[.appStorage("keyWidth"), default: 64.0] }
}

// MARK: - AppStorage String settings

extension SharedKey where Self == AppStorageKey<String>.Default {
  public static var lastReviewRequestVersion: Self { Self[.appStorage("lastReviewRequestVersion"), default: ""] }
  public static var lastShowedChangesVersion: Self { Self[.appStorage("lastShowedChangesVersion"), default: ""] }
}

// MARK: - AppStorage Date settings

extension SharedKey where Self == AppStorageKey<Date>.Default {
  public static var nextReviewRequestDate: Self { Self[.appStorage("nextReviewRequestDate"), default: .distantPast] }
}

// MARK: - AppStorage Int settings

extension SharedKey where Self == AppStorageKey<Int>.Default {
  public static var midiChannel: Self { Self[.appStorage("midiChannel"), default: 0] }
  public static var midiInputPortId: Self { Self[.appStorage("midiInputPortId"), default: 44_658]}
  public static var pitchBendRange: Self { Self[.appStorage("pitchBendRange"), default: 2] }
}

extension SharedKey where Self == AppStorageKey<ColorSchemeBehavior>.Default {
  public static var colorSchemeBehavior: Self { Self[.appStorage("colorSchemeBehavior"), default: .dark] }
}

extension SharedKey where Self == AppStorageKey<String>.Default {
  public static var favoriteSymbolName: Self { unsafe Self[.appStorage("favoriteSymbolName", store: .group), default: "star.circle.fill"] }
}

// MARK: - InMemory settings

extension SharedKey where Self == InMemoryKey<MIDIMonitor?>.Default {
  public static var midiMonitor: Self { Self[.inMemory("midiMonitor"), default: nil] }
}
