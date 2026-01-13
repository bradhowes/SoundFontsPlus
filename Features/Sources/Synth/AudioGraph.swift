// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio.AVAudioEngine
import BaseSupport
import Dependencies
import DependenciesMacros
import Sharing

private let log: Logger = .init(category: "AudioGraph")

@DependencyClient
public struct AudioGraph: Sendable {
  public var start: @Sendable (AVAudioUnitMIDIInstrument?) -> Bool = { _ in false }
  public var stop: @Sendable (AVAudioUnitMIDIInstrument?) -> Void
}

extension AudioGraph: DependencyKey {
  public static var liveValue: AudioGraph {
    let engine = AVAudioEngine()
    return .init(
      start: { startGraph(engine, synth: $0) },
      stop: { stopGraph(engine, synth: $0) }
    )
  }

  public static var previewValue: AudioGraph {
    .init(
      start: { _ in true },
      stop: { _ in }
    )
  }
}

private func startGraph(_ engine: AVAudioEngine, synth: AVAudioUnitMIDIInstrument?) -> Bool {
  log.info("startGraph BEGIN")
  guard let synth else {
    log.info("startGraph END - nil synth")
    return false
  }

  guard !engine.isRunning else {
    log.info("startGraph END - already running")
    return true
  }

  @Dependency(\.delayDevice) var delayDevice
  @Dependency(\.reverbDevice) var reverbDevice

  engine.attach(delayDevice.effect())
  engine.attach(reverbDevice.effect())
  engine.attach(synth)

  engine.connect(reverbDevice.effect(), to: engine.outputNode, format: AudioSession.audioFormat)
  engine.connect(delayDevice.effect(), to: reverbDevice.effect(), format: AudioSession.audioFormat)
  engine.connect(synth, to: delayDevice.effect(), format: AudioSession.audioFormat)

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

private func stopGraph(_ engine: AVAudioEngine, synth: AVAudioUnitMIDIInstrument?) {
  log.info("stopGraph BEGIN")

  guard let synth else {
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

  log.info("stopGraph - detaching delay")
  engine.detach(delayDevice.effect())

  log.info("stopGraph - detaching reverb")
  engine.detach(reverbDevice.effect())

  log.info("stopGraph - detaching synth")
  engine.detach(synth)

  log.info("stopGraph END")
}
