// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import Sharing

extension SharedKey where Self == AppStorageKey<Bool>.Default {
  public static var backgroundProcessing: Self { Self[.appStorage("backgroundProcessing"), default: true] }
  public static var duckOtherApps: Self { Self[.appStorage("duckOtherApps"), default: false] }
  public static var mixWithOtherApps: Self { Self[.appStorage("mixWithOtherApps"), default: true] }
  public static var playSoundOnPresetChange: Self { Self[.appStorage("playSoundOnPresetChange"), default: true] }
}

extension SharedKey where Self == AppStorageKey<KeyLabels>.Default {
  public static var keyLabels: Self { Self[.appStorage("keyLabels"), default: .cOnly] }
}

extension SharedKey where Self == AppStorageKey<Note>.Default {
  public static var firstVisibleKey: Self { Self[.appStorage("firstVisibleKey"), default: .C4] }
}

extension SharedKey where Self == InMemoryKey<Bool>.Default {
  public static var isAUv3: Self { Self[.inMemory("isAUv3"), default: false] }
}

extension SharedKey where Self == InMemoryKey<AUParameterTree>.Default {
  public static var parameterTree: Self {
    Self[.inMemory("parameterTree"), default: ParameterAddress.createParameterTree()]
  }
}
