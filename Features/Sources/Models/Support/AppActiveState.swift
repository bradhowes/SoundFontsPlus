// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
import Foundation
import Sharing

/**
 Getters and setters for active soundfont ID, preset ID, and tag ID. Use `@Dependency(\.appActiveState)` to access the right
 environmental collection.
 */
public struct AppActiveState: Sendable {

  public let setActiveSoundFontId: @Sendable (SoundFont.ID?) -> Void
  public let setActivePresetId: @Sendable (Preset.ID?) -> Void
  public let setActiveTagId: @Sendable (Tag.ID?) -> Void

  public let getActiveSoundFontId: @Sendable () -> SoundFont.ID?
  public let getActivePresetId: @Sendable () -> Preset.ID?
  public let getActiveTagId: @Sendable () -> Tag.ID?

  public init(
    setActiveSoundFontId: @Sendable @escaping (SoundFont.ID?) -> Void,
    setActivePresetId: @Sendable @escaping (Preset.ID?) -> Void,
    setActiveTagId: @Sendable @escaping (Tag.ID?) -> Void,
    getActiveSoundFontId: @Sendable @escaping () -> SoundFont.ID?,
    getActivePresetId: @Sendable @escaping () -> Preset.ID?,
    getActiveTagId: @Sendable @escaping () -> Tag.ID?
  ) {
    self.setActiveSoundFontId = setActiveSoundFontId
    self.setActivePresetId = setActivePresetId
    self.setActiveTagId = setActiveTagId
    self.getActiveSoundFontId = getActiveSoundFontId
    self.getActivePresetId = getActivePresetId
    self.getActiveTagId = getActiveTagId
  }
}

extension AppActiveState: DependencyKey {

  public static var liveValue: Self {
    return .init(
      setActiveSoundFontId: { value in
        @Shared(.appActiveStateValue) var activeStateValue
        $activeStateValue.activeSoundFontId.withLock { $0 = value}
      },
      setActivePresetId: { value in
        @Shared(.appActiveStateValue) var activeStateValue
        $activeStateValue.activePresetId.withLock { $0 = value}
      },
      setActiveTagId: { value in
        @Shared(.appActiveStateValue) var activeStateValue
        $activeStateValue.activeTagId.withLock { $0 = value}
      },
      getActiveSoundFontId: {
        @Shared(.appActiveStateValue) var activeStateValue
        return activeStateValue.activeSoundFontId
      },
      getActivePresetId: {
        @Shared(.appActiveStateValue) var activeStateValue
        return activeStateValue.activePresetId
      },
      getActiveTagId: {
        @Shared(.appActiveStateValue) var activeStateValue
        return activeStateValue.activeTagId
      }
    )
  }

  public static var previewValue: Self {
    return .init(
      setActiveSoundFontId: { value in
        @Shared(.tmpActiveStateValue) var activeStateValue
        $activeStateValue.activeSoundFontId.withLock { $0 = value}
      },
      setActivePresetId: { value in
        @Shared(.tmpActiveStateValue) var activeStateValue
        $activeStateValue.activePresetId.withLock { $0 = value}
      },
      setActiveTagId: { value in
        @Shared(.tmpActiveStateValue) var activeStateValue
        $activeStateValue.activeTagId.withLock { $0 = value}
      },
      getActiveSoundFontId: {
        @Shared(.tmpActiveStateValue) var activeStateValue
        return activeStateValue.activeSoundFontId
      },
      getActivePresetId: {
        @Shared(.tmpActiveStateValue) var activeStateValue
        return activeStateValue.activePresetId
      },
      getActiveTagId: {
        @Shared(.tmpActiveStateValue) var activeStateValue
        return activeStateValue.activeTagId
      }
    )
  }

  public static var testValue: Self { previewValue }
}

/**
 Holds the values of the active sountfont ID, preset ID, and tag ID.
 */
public struct AppActiveStateValue {
  public var activeSoundFontId: SoundFont.ID?
  public var activePresetId: Preset.ID?
  public var activeTagId: Tag.ID?

  init(activeSoundFontId: SoundFont.ID? = nil, activePresetId: Preset.ID? = nil, activeTagId: Tag.ID? = nil) {
    self.activeSoundFontId = activeSoundFontId
    self.activePresetId = activePresetId
    self.activeTagId = activeTagId
  }

  public static var `default`: AppActiveStateValue {
    .init(activeSoundFontId: 1, activePresetId: 1, activeTagId: Tag.Ubiquitous.all.id)
  }

  public static var none: AppActiveStateValue {
    .init(activeSoundFontId: nil, activePresetId: nil, activeTagId: nil)
  }
}

extension AppActiveStateValue: Codable, Equatable, Sendable {}

extension SharedKey where Self == FileStorageKey<AppActiveStateValue>.Default {
  fileprivate static var appActiveStateValue: Self { Self[.fileStorage(.appActiveStateURL), default: .default] }
}

extension SharedKey where Self == InMemoryKey<AppActiveStateValue>.Default {
  fileprivate static var tmpActiveStateValue: Self { Self[.inMemory("tmpActiveStateValue"), default: .default] }
}
