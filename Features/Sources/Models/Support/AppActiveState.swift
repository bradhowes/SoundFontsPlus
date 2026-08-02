// Copyright © 2025 Brad Howes. All rights reserved.

public import BaseSupport
public import Dependencies
import Foundation
public import Sharing
public import Tagged

/**
 Getters and setters for active soundfont ID, preset ID, and tag ID state values for the app.

 Use `@Dependency(\.appActiveState)` to access the right environmental collection.

 Note that this is **not** used by the AUv3 component. Rather, the audio unit host sets the `fullState` attribute of the AUv3
 component which holds encoded values for the active soundfont ID, preset ID, and tag ID state values (as well as others).
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

  @inlinable
  static func validateNotAUv3() {
#if DEBUG
    @Shared(.isAUv3) var isAUv3
    precondition(isAUv3 == false)
#endif
  }

  /// - returns: value to use in non-test situations
  public static var liveValue: Self {
    .init(
      setActiveSoundFontId: { value in
        validateNotAUv3()
        @Shared(.appActiveStateValue) var activeStateValue
        $activeStateValue.activeSoundFontId.withLock { $0 = value}
      },
      setActivePresetId: { value in
        validateNotAUv3()
        @Shared(.appActiveStateValue) var activeStateValue
        $activeStateValue.activePresetId.withLock { $0 = value}
      },
      setActiveTagId: { value in
        validateNotAUv3()
        @Shared(.appActiveStateValue) var activeStateValue
        $activeStateValue.activeTagId.withLock { $0 = value}
      },
      getActiveSoundFontId: {
        validateNotAUv3()
        @Shared(.appActiveStateValue) var activeStateValue
        return activeStateValue.activeSoundFontId
      },
      getActivePresetId: {
        validateNotAUv3()
        @Shared(.appActiveStateValue) var activeStateValue
        return activeStateValue.activePresetId
      },
      getActiveTagId: {
        validateNotAUv3()
        @Shared(.appActiveStateValue) var activeStateValue
        return activeStateValue.activeTagId
      }
    )
  }

  /// - returns: value to use in preview situations
  public static var previewValue: Self {
    .init(
      setActiveSoundFontId: { value in
        validateNotAUv3()
        @Shared(.tmpActiveStateValue) var activeStateValue
        $activeStateValue.activeSoundFontId.withLock { $0 = value}
      },
      setActivePresetId: { value in
        validateNotAUv3()
        @Shared(.tmpActiveStateValue) var activeStateValue
        $activeStateValue.activePresetId.withLock { $0 = value}
      },
      setActiveTagId: { value in
        validateNotAUv3()
        @Shared(.tmpActiveStateValue) var activeStateValue
        $activeStateValue.activeTagId.withLock { $0 = value}
      },
      getActiveSoundFontId: {
        validateNotAUv3()
        @Shared(.tmpActiveStateValue) var activeStateValue
        return activeStateValue.activeSoundFontId
      },
      getActivePresetId: {
        validateNotAUv3()
        @Shared(.tmpActiveStateValue) var activeStateValue
        return activeStateValue.activePresetId
      },
      getActiveTagId: {
        validateNotAUv3()
        @Shared(.tmpActiveStateValue) var activeStateValue
        return activeStateValue.activeTagId
      }
    )
  }

  /// - returns: value to use in testing situations
  public static var testValue: Self { previewValue }
}

/**
 Holds the values of the active sountfont ID, preset ID, and tag ID.
 */
public struct AppActiveStateValue {
  public var activeSoundFontId: SoundFont.ID?
  public var activePresetId: Preset.ID?
  public var activeTagId: Tag.ID?

  /**
   Create new container with the given state

   - parameter activeSoundFontId: the active sound font ID
   - parameter activePresetId: the active preset ID
   - parameter activeTagId: the active tag ID
   */
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
  static var appActiveStateValue: Self { Self[.fileStorage(.appActiveStateURL), default: .default] }
}

extension SharedKey where Self == InMemoryKey<AppActiveStateValue>.Default {
  static var tmpActiveStateValue: Self { Self[.inMemory("tmpActiveStateValue"), default: .default] }
}
