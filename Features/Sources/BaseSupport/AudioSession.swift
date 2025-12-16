// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio.AVAudioSession
import Dependencies
import DependenciesMacros

/**
 Collection of AVAudioSession dependencies to allow for mocking and controlling in tests.
 Currently only the `Synth` feature interacts with an `AudioSession` instance.
 */
@DependencyClient
public struct AudioSession: Sendable {
  public var start: @Sendable (AVAudioFormat) -> Bool = { _ in false }
  public var stop: @Sendable () -> Void
}

extension AudioSession: DependencyKey {

  public static var liveValue: AudioSession {
    .init(
      start: startAudioSession,
      stop: stopAudioSession
    )
  }

  public static var previewValue: AudioSession {
    .init(
      start: { _ in false },
      stop: { }
    )
  }
}

private func startAudioSession(_ audioFormat: AVAudioFormat) -> Bool {
  log.info("startAudioSession BEGIN")

#if os(iOS)
  let audioSession = AVAudioSession.sharedInstance()
  let bufferSize: Int = 64

  do {
    log.info("startAudioSession - setting AudioSession category")
    try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
  } catch let error as NSError {
    let err = error.localizedDescription
    log.error("startAudioSession - failed to set the audio session category and mode: \(err)")
  }

  log.info("startAudioSession - current sampleRate: \(audioSession.sampleRate)")

  do {
    log.info("configureAudioSession - setting preferred sample rate")
    try audioSession.setPreferredSampleRate(audioFormat.sampleRate)
  } catch let error as NSError {
    let err = error.localizedDescription
    log.error("configureAudioSession - failed to set the preferred sample rate to \(audioFormat.sampleRate) - \(err)")
  }

  let bufferDuration = Double(bufferSize) / audioFormat.sampleRate
  do {
    log.info("configureAudioSession - setting IO buffer duration \(bufferDuration)")
    try audioSession.setPreferredIOBufferDuration(bufferDuration)
  } catch let error as NSError {
    let err = error.localizedDescription
    log.error("configureAudioSession - failed to set the preferred buffer size to \(bufferSize) - \(err)")
  }

  audioSession.currentRoute.dump()

  let activated: Bool
  do {
    log.info("startAudioSession - making audio session active")
    try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
    activated = true
  } catch {
    let err = error.localizedDescription
    log.error("startAudioSession - failed to set active - \(err)")
    activated = false
  }

  log.info("startAudioSession END - \(activated)")

  return activated

#else
  return true
#endif
}

private func stopAudioSession() {
  log.info("stopAudioSession BEGIN")
#if os(iOS)
  do {
    log.info("stopAudioSession - deactivating AudioSession")
    try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    log.info("stopAudioSession - done")
  } catch let error as NSError {
    log.error("stopAudioSession - Failed session.setActive(false): \(error.localizedDescription)")
  }
#endif
  log.info("stopAudioSession END")
}

#if os(iOS)
extension AVAudioSessionRouteDescription {
  fileprivate func dump() {
    for input in self.inputs {
      log.debug("AVAudioSession input - \(input.portName)")
    }
    for output in self.outputs {
      log.debug("AVAudioSession output - \(output.portName)")
    }
  }
}
#endif

private let log = Logger(category: "AudioSession")
