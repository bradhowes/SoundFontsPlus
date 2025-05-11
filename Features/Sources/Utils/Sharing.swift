import Sharing

extension SharedKey where Self == AppStorageKey<Bool>.Default {
  public static var keyboardSlides: Self { Self[.appStorage("keyboardSlides"), default: false] }
  public static var showSolfegeTags: Self { Self[.appStorage("showSolfegeTags"), default: false] }
  public static var midiAutoConnect: Self { Self[.appStorage("midiAutoConnect"), default: true] }
  public static var backgroundProcessing: Self { Self[.appStorage("backgroundProcessing"), default: true] }
  public static var globalTuningEnabled: Self { Self[.appStorage("globalTuningEnabled"), default: false] }
}

extension SharedKey where Self == AppStorageKey<Double>.Default {
  public static var keyWidth: Self { Self[.appStorage("keyWidth"), default: 64.0] }
  public static var globalTuningCents: Self { Self[.appStorage("globalTuningCents"), default: 0.0 ] }
}

extension SharedKey where Self == AppStorageKey<KeyLabels>.Default {
  public static var keyLabels: Self { Self[.appStorage("keyLabels"), default: .cOnly] }
}

extension SharedKey where Self == AppStorageKey<Note>.Default {
  public static var lowestKey: Self { Self[.appStorage("lowestKey"), default: Note(midiNoteValue: 60)] }
  public static var highestKey: Self { Self[.appStorage("highestKey"), default: Note(midiNoteValue: 61)] }
}

extension SharedKey where Self == AppStorageKey<Int>.Default {
  public static var midiChannel: Self { Self[.appStorage("midiChannel"), default: 0] }
  public static var pitchBendRange: Self { Self[.appStorage("pitchBendRange"), default: 2] }
}
