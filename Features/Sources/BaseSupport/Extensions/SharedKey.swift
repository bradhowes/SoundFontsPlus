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

extension SharedKey where Self == InMemoryKey<Bool>.Default {
  public static var isAUv3: Self { Self[.inMemory("isAUv3"), default: false] }
}

extension SharedKey where Self == InMemoryKey<AUAudioUnit?>.Default {
  /// The auAudioUnit is the low-level `SF2LibAU` instance.
  public static var auAudioUnit: Self { Self[.inMemory("auAudioUnit"), default: nil] }
}

extension SharedKey where Self == InMemoryKey<AVAudioUnit?>.Default {
  /// The avAudioUnit is an `AVAudioUnit` wrapper around an `SF2LibAU` instance. It is only available when running
  /// the application, not the AUv3 extension.
  public static var avAudioUnit: Self { Self[.inMemory("avAudioUnit"), default: nil] }
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
