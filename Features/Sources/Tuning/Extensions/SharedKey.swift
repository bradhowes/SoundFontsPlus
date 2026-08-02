// Copyright © 2025 Brad Howes. All rights reserved.

public import Sharing

extension SharedKey where Self == AppStorageKey<Bool>.Default {
  public static var globalTuningEnabled: Self { Self[.appStorage("globalTuningEnabled"), default: false] }
}

extension SharedKey where Self == AppStorageKey<Double>.Default {
  public static var globalTuningFrequency: Self { Self[.appStorage("globalTuningFrequency"), default: 440.0] }
}
