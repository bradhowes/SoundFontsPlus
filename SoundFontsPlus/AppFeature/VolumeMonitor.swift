// Copyright © 2025 Brad Howes. All rights reserved.

import AVKit
import os
import ProgressHUD
import Sharing

private let log = Logger(category: "VolumeMonitor")

/// Monitor volume setting on device and the "silence" or "mute" switch. When there is no apparent audio
/// output, update the Keyboard and NotePlayer instances so that they can show an indication to the user.
public actor VolumeMonitor {

  private enum Reason {
    /// Volume level is at zero
    case volumeLevel
    /// There is no preset active in the synth
    case noPreset
  }

  private var reason: Reason?
  private var sessionVolumeObserver: NSKeyValueObservation?

  /**
   Begin monitoring volume of the given AVAudioSession

   - parameter session: the AVAudioSession to monitor
   */
  func start() {
    log.info("start")
    reason = nil
    let session = AVAudioSession.sharedInstance()
    sessionVolumeObserver = session.observe(\.outputVolume, options: [.new], changeHandler: self.volumeChanged)
    volumeChanged(session.outputVolume)
  }

  /**
   Stop monitoring the output volume of an AVAudioSession
   */
  func stop() {
    log.info("stop")
    reason = nil
    sessionVolumeObserver?.invalidate()
    sessionVolumeObserver = nil
  }

  func presetChanged(_ presetId: Preset.ID?) {
    let volume = AVAudioSession.sharedInstance().outputVolume
    checkState(volume: volume, activePresetId: presetId)
  }
}

extension VolumeMonitor {

  /**
   Show any previously-posted silence reason.
   */
  func repostNotice() { showReason() }
}

extension VolumeMonitor {

  private func volumeChanged(_ session: AVAudioSession, _ change: NSKeyValueObservedChange<Float>) {
    guard let value = change.newValue else { return }
    volumeChanged(value)
  }

  private func volumeChanged(_ value: Float) {
    @Shared(.activeState) var activeState
    checkState(volume: value, activePresetId: activeState.activePresetId)
  }

  private func checkState(volume: Float, activePresetId: Preset.ID?) {
    if volume < 0.01 {
      reason = .volumeLevel
    } else if activePresetId == nil {
      reason = .noPreset
    } else {
      reason = .none
    }

    self.showReason()
  }

  private func showReason() {
    let reason = self.reason
    DispatchQueue.main.async {
      switch reason {
      case .volumeLevel: ProgressHUD.banner("Volume", "Volume set to 0.")
      case .noPreset: ProgressHUD.banner("Preset", "No active preset.")
      case .none: ProgressHUD.bannerHide()
      }
    }
  }
}
