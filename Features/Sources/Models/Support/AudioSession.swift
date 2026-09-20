// Copyright © 2025 Brad Howes. All rights reserved.

public import AVFAudio.AVAudioSession
import BaseSupport
public import Dependencies
import DependenciesMacros
import Sharing

/**
 Collection of AVAudioSession dependencies to allow for mocking and controlling in tests.

 An audio session is really only applicable to iOS/iPadOS devices, but we always use an AudioSession dependency regardless of
 platform and we do not do anything in the closure operations on macOS platforms.

 Currently only the `Synth` feature interacts with an `AudioSession` instance.
 */
@DependencyClient
public struct AudioSession: Sendable {

  public static let audioFormat: AVAudioFormat! = AVAudioFormat(
    commonFormat: .pcmFormatFloat32,
    sampleRate: 48_000.0,
    channels: 2,
    interleaved: false
  )

  public let start: @Sendable () async -> Bool
  public let stop: @Sendable () async -> Void

  public init(
    start: @Sendable @escaping () async -> Bool,
    stop: @Sendable @escaping () async -> Void
  ) {
    self.start = start
    self.stop = stop
  }
}

extension AudioSession {

  public func restart() async -> Bool {
    await stop()
    return await start()
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

private func startAudioSession() async -> Bool {
  log.info("startAudioSession BEGIN")

#if os(iOS)
  let audioSession = AVAudioSession.sharedInstance()

  setCategory(audioSession)
  setSampleRate(audioSession, audioFormat: AudioSession.audioFormat)
  setBufferDuration(audioSession, audioFormat: AudioSession.audioFormat)

  audioSession.currentRoute.dump()

  log.info("startAudioSession - making audio session active")
  let activated: Bool
  if #available(iOS 27.0, *) {
    activated = await withCheckedContinuation { continuation in
      audioSession.activate { activated, error in
        if let error {
          log.error("startAudioSession - failed to set active - \(error.localizedDescription)")
        }
        continuation.resume(returning: activated)
      }
    }
  } else {
    activated = await withCheckedContinuation { continuation in
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          try audioSession.setActive(true)
          continuation.resume(returning: true)
        } catch {
          log.error("startAudioSession - failed to set active - \(error.localizedDescription)")
          continuation.resume(returning: false)
        }
      }
    }
  }

  log.info("startAudioSession END - \(activated)")

  return activated

#else
  return true
#endif
}

private func stopAudioSession() async {
  log.info("stopAudioSession BEGIN")
#if os(iOS)
  log.info("stopAudioSession - deactivating AudioSession")
  if #available(iOS 27.0, *) {
    await withCheckedContinuation { continuation in
      AVAudioSession.sharedInstance().deactivate(options: [.notifyOthersOnDeactivation]) { deactivated, error in
        if let error {
          log.error("stopAudioSession - failed to deactivate: \(error.localizedDescription)")
        } else if deactivated {
          log.info("stopAudioSession - done")
        }
        continuation.resume()
      }
    }
  } else {
    await withCheckedContinuation { continuation in
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
          log.info("stopAudioSession - done")
        } catch {
          log.error("stopAudioSession - failed to deactivate: \(error.localizedDescription)")
        }
        continuation.resume()
      }
    }
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
  @Shared(.duckOtherApps) var duckOtherApps
  @Shared(.mixWithOtherApps) var mixWithOtherApps

  var options: AVAudioSession.CategoryOptions = [.allowAirPlay]
  if duckOtherApps {
    options.insert(.duckOthers)
  } else if mixWithOtherApps {
    options.insert(.mixWithOthers)
  }

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
