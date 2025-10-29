// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import Sharing

extension SharedKey where Self == AppStorageKey<Bool>.Default {
  public static var backgroundProcessing: Self { Self[.appStorage("backgroundProcessing"), default: true] }
  public static var playSoundOnPresetChange: Self { Self[.appStorage("playSoundOnPresetChange"), default: true] }
}

extension SharedKey where Self == AppStorageKey<KeyLabels>.Default {
  public static var keyLabels: Self { Self[.appStorage("keyLabels"), default: .cOnly] }
}

extension SharedKey where Self == AppStorageKey<Note>.Default {
  public static var firstVisibleKey: Self { Self[.appStorage("firstVisibleKey"), default: .C4] }
}

extension SharedKey where Self == InMemoryKey<AVAudioUnit?>.Default {
  public static var synthAudioUnit: Self { Self[.inMemory("synthAudioUnit"), default: nil] }
}

extension SharedKey where Self == InMemoryKey<AVAudioUnitDelay?>.Default {
  public static var delayEffect: Self { Self[.inMemory("delayEffect"), default: nil] }
}

extension SharedKey where Self == InMemoryKey<AVAudioUnitReverb?>.Default {
  public static var reverbEffect: Self { Self[.inMemory("reverbEffect"), default: nil] }
}

extension SharedKey where Self == InMemoryKey<AVAudioEngine?>.Default {
  public static var audioEngine: Self { Self[.inMemory("audioEngine"), default: nil] }
}

extension SharedKey where Self == InMemoryKey<AUParameterTree>.Default {
  public static var parameterTree: Self {
    Self[.inMemory("parameterTree"), default: ParameterAddress.createParameterTree()]
  }
}
