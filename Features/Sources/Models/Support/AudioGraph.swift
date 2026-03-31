// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio.AVAudioEngine
import BaseSupport
import Dependencies
import DependenciesMacros
import Sharing

@DependencyClient
public struct AudioGraph: Sendable {
  public let engine: AVAudioEngine?
  public let start: @Sendable (AVAudioEngine?, AVAudioUnitMIDIInstrument?) -> Bool
  public let stop: @Sendable (AVAudioEngine?, AVAudioUnitMIDIInstrument?) -> Void

  public init(
    engine: AVAudioEngine?,
    start: @Sendable @escaping (AVAudioEngine?, AVAudioUnitMIDIInstrument?) -> Bool,
    stop: @Sendable @escaping (AVAudioEngine?, AVAudioUnitMIDIInstrument?) -> Void
  ) {
    self.engine = engine
    self.start = start
    self.stop = stop
  }
}

extension AudioGraph: DependencyKey {
  public static var liveValue: AudioGraph {
    .init(
      engine: AVAudioEngine(),
      start: { startGraph($0, synth: $1) },
      stop: { stopGraph($0, synth: $1) }
    )
  }

  public static var previewValue: AudioGraph {
    .init(
      engine: nil,
      start: { _, _ in true },
      stop: { _, _ in }
    )
  }
}

private func startGraph(_ engine: AVAudioEngine?, synth: AVAudioUnitMIDIInstrument?) -> Bool {
  log.info("startGraph BEGIN")
  guard
    let engine,
    let synth
  else {
    log.info("startGraph END - nil synth")
    return false
  }

  guard !engine.isRunning else {
    log.info("startGraph END - already running")
    return true
  }

  @Dependency(\.delayDevice) var delayDevice
  @Dependency(\.reverbDevice) var reverbDevice

  let reverb = reverbDevice.effect
  if let reverb {
    engine.attach(reverb)
    engine.connect(reverb, to: engine.outputNode, format: AudioSession.audioFormat)
  }

  let delay = delayDevice.effect
  if let delay {
    engine.attach(delay)
    engine.connect(delay, to: reverb ?? engine.outputNode, format: AudioSession.audioFormat)
  }

  engine.attach(synth)
  engine.connect(synth, to: delay ?? reverb ?? engine.outputNode, format: AudioSession.audioFormat)

  let started: Bool
  do {
    log.info("startGraph - starting")
    try engine.start()
    started = true
  } catch {
    log.error("startGraph - failed to start - \(error.localizedDescription)")
    started = false
  }

  log.info("startGraph END - \(started)")
  return started
}

private func stopGraph(_ engine: AVAudioEngine?, synth: AVAudioUnitMIDIInstrument?) {
  log.info("stopGraph BEGIN")

  guard
    let engine,
    let synth
  else {
    log.info("stopGraph END - nil synth")
    return
  }

  synth.reset()

  guard engine.isRunning else {
    log.info("stopGraph END - already stopped")
    return
  }

  @Dependency(\.delayDevice) var delayDevice
  @Dependency(\.reverbDevice) var reverbDevice

  log.info("stopGraph - stopping engine")
  engine.stop()

  if let delay = delayDevice.effect {
    log.info("stopGraph - detaching delay")
    engine.detach(delay)
  }

  if let reverb = reverbDevice.effect {
    log.info("stopGraph - detaching reverb")
    engine.detach(reverb)
  }

  log.info("stopGraph - detaching synth")
  engine.detach(synth)

  log.info("stopGraph END")
}

private let log: Logger = .init(category: "AudioGraph")
