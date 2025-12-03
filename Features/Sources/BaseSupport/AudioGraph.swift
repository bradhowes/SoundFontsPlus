// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio.AVAudioEngine
import Dependencies
import DependenciesMacros
import Sharing

private let log = Logger(category: "AudioGraph")

@DependencyClient
public struct AudioGraph: Sendable {
  public var start: @Sendable (AVAudioFormat, AVAudioUnitMIDIInstrument) -> Bool = { _, _ in false }
  public var stop: @Sendable (AVAudioUnitMIDIInstrument) -> Void
}

extension AudioGraph: DependencyKey {
  public static var liveValue: AudioGraph {
    .init(
      start: startGraph,
      stop: stopGraph
    )
  }

  public static var previewValue: AudioGraph {
    .init(
      start: { _, _ in true },
      stop: { _ in }
    )
  }
}

private func startGraph(_ audioFormat: AVAudioFormat, _ synth: AVAudioUnitMIDIInstrument) -> Bool {
  @Shared(.audioEngine) var audioEngine
  @Shared(.delayEffect) var delayEffect
  @Shared(.reverbEffect) var reverbEffect

  log.info("startGraph BEGIN")
  guard
    let audioEngine,
    let delayEffect,
    let reverbEffect
  else {
    log.info("startGraph END - missing components")
    return false
  }

  guard !audioEngine.isRunning else {
    log.info("startGraph END - already running")
    return true
  }

  log.info("startGraph - attaching audio units to engine")
  audioEngine.attach(synth)
  audioEngine.attach(delayEffect)
  audioEngine.attach(reverbEffect)

  log.info("startGraph - connecting audio units together")
  audioEngine.connect(reverbEffect, to: audioEngine.outputNode, format: audioFormat)
  audioEngine.connect(delayEffect, to: reverbEffect, format: audioFormat)
  audioEngine.connect(synth, to: delayEffect, format: audioFormat)

  let started: Bool
  do {
    log.info("startGraph - starting")
    try audioEngine.start()
    started = true
  } catch {
    log.error("startGraph - failed to start - \(error.localizedDescription)")
    started = false
  }

  log.info("startGraph END - \(started)")
  return started
}

private func stopGraph(_ synth: AVAudioUnitMIDIInstrument) {
  @Shared(.audioEngine) var audioEngine
  @Shared(.delayEffect) var delayEffect
  @Shared(.reverbEffect) var reverbEffect

  log.info("stopGraph BEGIN")
  guard
    let audioEngine,
    let delayEffect,
    let reverbEffect
  else {
    log.info("stopGraph END - missing components")
    return
  }

  log.info("stopGraph - resetting synth")
  synth.reset()

  guard audioEngine.isRunning else {
    log.info("stopGraph END - already stopped")
    return
  }

  log.info("stopGraph - stopping engine")
  audioEngine.stop()

  log.info("stopGraph - detaching delay")
  audioEngine.detach(delayEffect)

  log.info("stopGraph - detaching reverb")
  audioEngine.detach(reverbEffect)

  log.info("stopGraph - detaching synth")
  audioEngine.detach(synth)

  log.info("stopGraph END")
}
