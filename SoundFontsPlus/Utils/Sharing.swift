import Foundation
import Sharing
import Tagged

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
}

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

extension SharedKey where Self == AppStorageKey<Int>.Default {
  public static var midiChannel: Self { Self[.appStorage("midiChannel"), default: 0] }
  public static var pitchBendRange: Self { Self[.appStorage("pitchBendRange"), default: 2] }
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
