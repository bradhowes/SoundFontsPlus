// Copyright © 2025 Brad Howes. All rights reserved.

import AVKit
import os
import ProgressHUD

/// Monitor volume setting on device and the "silence" or "mute" switch. When there is no apparent audio
/// output, update the Keyboard and NotePlayer instances so that they can show an indication to the user.
final class VolumeMonitor {

  private let logger = Logger(category: "VolumeMonitor")

  private enum Reason {
    /// Volume level is at zero
    case volumeLevel
    /// There is no preset active in the synth
    case noPreset
  }

  private var volume: Float = 1.0 {
    didSet {
      logger.info("volume changed: \(volume)")
      update()
    }
  }

  private var reason: Reason?
  private var sessionVolumeObserver: NSKeyValueObservation?

  /// Set to true if there is a valid preset installed and in use by the synth.
  public var validActivePreset = true
}

extension VolumeMonitor {

  /**
   Begin monitoring volume of the given AVAudioSession

   - parameter session: the AVAudioSession to monitor
   */
  func start() {
    logger.info("start")
    reason = nil
    let session = AVAudioSession.sharedInstance()
    sessionVolumeObserver = session.observe(\.outputVolume) { [weak self] session, _ in
      self?.volume = session.outputVolume
    }
    volume = session.outputVolume
  }

  /**
   Stop monitoring the output volume of an AVAudioSession
   */
  func stop() {
    logger.info("stop")
    reason = nil
    sessionVolumeObserver?.invalidate()
    sessionVolumeObserver = nil
  }
}

extension VolumeMonitor {

  /**
   Show any previously-posted silence reason.
   */
  func repostNotice() { showReason() }
}

extension VolumeMonitor {

  private func update() {
    if volume < 0.01 {
      reason = .volumeLevel
    } else if !validActivePreset {
      reason = .noPreset
    } else {
      reason = .none
    }

    showReason()
  }

  private func showReason() {
    switch reason {
    case .volumeLevel: ProgressHUD.banner("Volume", "Volume set to 0.")
    case .noPreset: ProgressHUD.banner("Preset", "No active preset.")
    case .none: ProgressHUD.bannerHide()
    }
  }
}
