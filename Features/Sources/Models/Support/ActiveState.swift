// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import Sharing
import Tagged

public struct ActiveState: Codable, Equatable, Sendable {

  public var activeSoundFontId: SoundFont.ID?
  public var activePresetId: Preset.ID?
  public var activeTagId: FontTag.ID?
  public var activeDelayConfigId: DelayConfig.ID?
  public var activeReverbConfigId: ReverbConfig.ID?

  public init(
    activeSoundFontId: SoundFont.ID?,
    activePresetId: Preset.ID?,
    activeTagId: FontTag.ID?,
    activeDelayConfigId: DelayConfig.ID?,
    activeReverbConfigId: ReverbConfig.ID?
  ) {
    self.activeSoundFontId = activeSoundFontId
    self.activePresetId = activePresetId
    self.activeTagId = activeTagId
    self.activeDelayConfigId = activeDelayConfigId
    self.activeReverbConfigId = activeReverbConfigId
  }

  public static var `default`: Self {
    .init(
      activeSoundFontId: 1,
      activePresetId: 1,
      activeTagId: FontTag.Ubiquitous.all.id,
      activeDelayConfigId: nil,
      activeReverbConfigId: nil
    )
  }

  public static var none: Self {
    .init(
      activeSoundFontId: nil,
      activePresetId: nil,
      activeTagId: nil,
      activeDelayConfigId: nil,
      activeReverbConfigId: nil
    )
  }

  public static var value: ActiveState {
    @Shared(.isAUv3) var isAUv3
    if isAUv3 {
      @Shared(.auv3ActiveState) var activeState
      return activeState
    } else {
      @Shared(.appActiveState) var activeState
      return activeState
    }
  }

  public static func setSoundFontId(_ value: SoundFont.ID?) {
    @Shared(.isAUv3) var isAUv3
    if isAUv3 {
      @Shared(.auv3ActiveState) var activeState
      $activeState.withLock { $0.activeSoundFontId = value }
    } else {
      @Shared(.appActiveState) var activeState
      $activeState.withLock { $0.activeSoundFontId = value }
    }
  }

  public static func setPresetId(_ value: Preset.ID?) {
    @Shared(.isAUv3) var isAUv3
    if isAUv3 {
      @Shared(.auv3ActiveState) var activeState
      $activeState.withLock { $0.activePresetId = value }
    } else {
      @Shared(.appActiveState) var activeState
      $activeState.withLock { $0.activePresetId = value }
    }
  }

  public static func setTagId(_ value: FontTag.ID?) {
    @Shared(.isAUv3) var isAUv3
    if isAUv3 {
      @Shared(.auv3ActiveState) var activeState
      $activeState.withLock { $0.activeTagId = value }
    } else {
      @Shared(.appActiveState) var activeState
      $activeState.withLock { $0.activeTagId = value }
    }
  }

  public static func setDelayConfigId(_ value: DelayConfig.ID?) {
    @Shared(.isAUv3) var isAUv3
    if isAUv3 {
      @Shared(.auv3ActiveState) var activeState
      $activeState.withLock { $0.activeDelayConfigId = value }
    } else {
      @Shared(.appActiveState) var activeState
      $activeState.withLock { $0.activeDelayConfigId = value }
    }
  }

  public static func setReverbConfigId(_ value: ReverbConfig.ID?) {
    @Shared(.isAUv3) var isAUv3
    if isAUv3 {
      @Shared(.auv3ActiveState) var activeState
      $activeState.withLock { $0.activeReverbConfigId = value }
    } else {
      @Shared(.appActiveState) var activeState
      $activeState.withLock { $0.activeReverbConfigId = value }
    }
  }
}
