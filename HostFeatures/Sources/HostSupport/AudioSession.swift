// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio.AVAudioSession
import Dependencies
import OSLog
import Sharing

/**
 Collection of AVAudioSession dependencies to allow for mocking and controlling in tests.
 Currently only the `Synth` feature interacts with an `AudioSession` instance.
 */
public struct AudioSession: Sendable {

  public static let audioFormat: AVAudioFormat! = AVAudioFormat(
    commonFormat: .pcmFormatFloat32,
    sampleRate: 48_000.0,
    channels: 2,
    interleaved: false
  )

  public var start: @Sendable () -> Bool = { false }
  public var stop: @Sendable () -> Void
}

extension AudioSession {

  public func restart() -> Bool {
    stop()
    return start()
  }
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
      start: { false },
      stop: { }
    )
  }
}

private func startAudioSession() -> Bool {
  log.info("startAudioSession BEGIN")

#if os(iOS)
  let audioSession = AVAudioSession.sharedInstance()

  setCategory(audioSession)
  setSampleRate(audioSession, audioFormat: AudioSession.audioFormat)
  setBufferDuration(audioSession, audioFormat: AudioSession.audioFormat)

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
#endif // os(iOS)
  log.info("stopAudioSession END")
}

#if os(iOS)

private func setBufferDuration(_ audioSession: AVAudioSession, audioFormat: AVAudioFormat) {
  let bufferSize: Int = 64
  let bufferDuration = Double(bufferSize) / audioFormat.sampleRate
  do {
    log.info("configureAudioSession - setting IO buffer duration \(bufferDuration)")
    try audioSession.setPreferredIOBufferDuration(bufferDuration)
  } catch let error as NSError {
    let err = error.localizedDescription
    log.error("configureAudioSession - failed to set the preferred buffer size to \(bufferSize) - \(err)")
  }
}

private func setSampleRate(_ audioSession: AVAudioSession, audioFormat: AVAudioFormat) {
  log.info("startAudioSession - current sampleRate: \(audioSession.sampleRate)")

  do {
    log.info("configureAudioSession - setting preferred sample rate")
    try audioSession.setPreferredSampleRate(audioFormat.sampleRate)
  } catch let error as NSError {
    let err = error.localizedDescription
    log.error("configureAudioSession - failed to set the preferred sample rate to \(audioFormat.sampleRate) - \(err)")
  }
}

private func setCategory(_ audioSession: AVAudioSession) {
  let options: AVAudioSession.CategoryOptions = [.allowAirPlay, .mixWithOthers]
  do {
    log.info("startAudioSession - setting AudioSession category")
    try audioSession.setCategory(
      .playback,
      mode: .default,
      options: options
    )
  } catch let error as NSError {
    let err = error.localizedDescription
    log.error("startAudioSession - failed to set the audio session category and mode: \(err)")
  }
}

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

#endif // os(iOS)

private let log: Logger = .init(category: "AudioSession")
