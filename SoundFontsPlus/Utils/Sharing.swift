// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import Combine
import MorkAndMIDI
import SF2LibAU
import Sharing
import Tagged

// MARK: - AppStorage Bool settings

extension SharedKey where Self == AppStorageKey<Bool>.Default {
  public static var backgroundProcessing: Self { Self[.appStorage("backgroundProcessing"), default: true] }
  public static var delayLockEnabled: Self { Self[.appStorage("delayLockEnabled"), default: false] }
  public static var effectsVisible: Self { Self[.appStorage("effectsVisible"), default: false] }
  public static var favoritesOnTop: Self { Self[.appStorage("favoritesOnTop"), default: false] }
  public static var globalTuningEnabled: Self { Self[.appStorage("globalTuningEnabled"), default: false] }
  public static var keyboardSlides: Self { Self[.appStorage("keyboardSlides"), default: false] }
  public static var midiAutoConnect: Self { Self[.appStorage("midiAutoConnect"), default: true] }
  public static var reverbLockEnabled: Self { Self[.appStorage("reverbLockEnabled"), default: false] }
  public static var showOnlyFavorites: Self { Self[.appStorage("showOnlyFavorites"), default: false] }
  public static var showSolfegeTags: Self { Self[.appStorage("showSolfegeTags"), default: false] }
  public static var starFavoriteNames: Self { Self[.appStorage("starFavoriteNames"), default: true] }
  public static var tagsListVisible: Self { Self[.appStorage("tagsListVisible"), default: false] }
  public static var playSoundOnPresetChange: Self { Self[.appStorage("playSoundOnPresetChange"), default: true] }
  public static var copyFileWhenInstalling: Self { Self[.appStorage("copyFileWhenInstalling"), default: true]}
}

// MARK: - AppStorage Double settings

extension SharedKey where Self == AppStorageKey<Double>.Default {
  public static var fontsAndPresetsSplitPosition: Self {
    Self[.appStorage("fontsAndPresetsSplitPosition"), default: 0.5]
  }
  public static var fontsAndTagsSplitPosition: Self {
    Self[.appStorage("fontsAndTagsSplitPosition"), default: 0.4]
  }
  public static var globalTuning: Self { Self[.appStorage("globalTuning"), default: 440.0 ] }
  public static var keyWidth: Self { Self[.appStorage("keyWidth"), default: 64.0] }
}

// MARK: - AppStorage Int settings

extension SharedKey where Self == AppStorageKey<Int>.Default {
  public static var midiChannel: Self { Self[.appStorage("midiChannel"), default: 0] }
  public static var pitchBendRange: Self { Self[.appStorage("pitchBendRange"), default: 2] }
  public static var midiInputPortId: Self { Self[.appStorage("midiInputPortId"), default: 44_658]}
}

extension SharedKey where Self == AppStorageKey<KeyLabels>.Default {
  public static var keyLabels: Self { Self[.appStorage("keyLabels"), default: .cOnly] }
}

extension SharedKey where Self == AppStorageKey<Note>.Default {
  public static var firstVisibleKey: Self { Self[.appStorage("firstVisibleKey"), default: .C4] }
}

extension SharedKey where Self == AppStorageKey<String>.Default {
  public static var favoriteSymbolName: Self { Self[.appStorage("favoriteSymbolName"), default: "star.circle.fill"] }
}

extension URL {
  static public let activeStateURL = FileManager.default.sharedDocumentsDirectory.appendingPathComponent("activeState.json")
}

extension SharedKey where Self == FileStorageKey<ActiveState>.Default {
  public static var activeState: Self {
    Self[.fileStorage(.activeStateURL), default: .init()]
  }
}

// MARK: - InMemory settings

extension SharedKey where Self == InMemoryKey<AUParameterTree>.Default {
  public static var parameterTree: Self {
    Self[.inMemory("parameterTree"), default: ParameterAddress.createParameterTree()]
  }
}

extension SharedKey where Self == InMemoryKey<MIDI?>.Default {
  public static var midi: Self { Self[.inMemory("midi"), default: nil] }
}

extension SharedKey where Self == InMemoryKey<MIDIMonitor?>.Default {
  public static var midiMonitor: Self { Self[.inMemory("midiMonitor"), default: nil] }
}

extension SharedKey where Self == InMemoryKey<AVAudioUnit?>.Default {
  public static var avAudioUnit: Self { Self[.inMemory("avAudioUnit"), default: nil] }
}

extension AVAudioUnit {
  var midiInstrument: AVAudioUnitMIDIInstrument? { self as? AVAudioUnitMIDIInstrument }
  var synth: SF2LibAU? { self.auAudioUnit as? SF2LibAU }
}
