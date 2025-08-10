// Copyright © 2025 Brad Howes. All rights reserved.

import AUv3Shared
import AudioToolbox
import ComposableArchitecture
import CoreAudioKit
import os
import SF2LibAU
import Sharing
import SwiftUI

private let log = Logger(category: "Database")

@Reducer
public struct SynthFeature {
  let sampleRate: Double = 48_000.0

  @ObservableState
  public struct State {
    let engine = AVAudioEngine()
    var avAudioUnit: AVAudioUnit?
    var midiSynth: AVAudioUnitMIDIInstrument? { avAudioUnit as? AVAudioUnitMIDIInstrument }
    var audioUnit: SF2LibAU? { avAudioUnit?.auAudioUnit as? SF2LibAU }
    @ObservationStateIgnored
    var loadedSoundFontId: SoundFont.ID?
    @ObservationStateIgnored
    var loadedPresetIndex: Int?
    @ObservationStateIgnored
    var observers = [NSObjectProtocol]()
  }

  public enum Action {
    case activePresetIdChanged
    case delegate(Delegate)
    case initialize
    case routeChanged
    case useAudioUnit(AVAudioUnit)
    public enum Delegate {
      case activeSynth(SF2LibAU, AVAudioUnitMIDIInstrument)
    }
  }

  private enum CancelId {
    case createSynth
    case monitorActivePresetId
    case monitorRouteChanged
    case playSample
  }

  public var body: some ReducerOf<Self> {

    Reduce { state, action in
      switch action {
      case .activePresetIdChanged: return activePresetIdChanged(&state)
      case .delegate: return .none
      case .initialize: return initialize(&state)
      case .routeChanged: return routeChanged(&state)
      case .useAudioUnit(let audioUnit): return useAudioUnit(&state, audioUnit: audioUnit)
      }
    }
  }

  @Dependency(\.defaultDatabase) var database
  @Shared(.activeState) var activeState
}

extension SF2LibAU: @retroactive @unchecked Sendable {}

private extension SynthFeature {

  func activePresetIdChanged(_ state: inout State) -> Effect<Action> {
    guard let audioUnit = state.audioUnit else {
      log.info("nil audioUnit -- ignoring")
      return .none
    }

    guard let presetInfo = Operations.activePresetLoadingInfo else {
      log.info("no presetInfo -- ignoring")
      return .none
    }

    guard state.loadedPresetIndex != presetInfo.presetIndex || state.loadedSoundFontId != presetInfo.soundFontId else {
      log.info("already loaded")
      return .none
    }

    let result: Bool
    if presetInfo.soundFontId == state.loadedSoundFontId {
      log.info("loading preset \(presetInfo.presetIndex) \(presetInfo.presetName)")
      result = audioUnit.sendUsePreset(preset: presetInfo.presetIndex)
    } else {
      guard let location = try? SoundFontKind(kind: presetInfo.kind, location: presetInfo.location)
      else {
        log.error("unexpected nil location for \(presetInfo)")
        return .none
      }
      let path = location.path.path(percentEncoded: false)
      log.info("loading \(path) -- preset \(presetInfo.presetIndex) \(presetInfo.presetName)")
      result = audioUnit.sendLoadFileUsePreset(path: path, preset: presetInfo.presetIndex)
    }

    log.info("loaded \(result)")
    if result {
      let firstTime = state.loadedSoundFontId == nil
      state.loadedSoundFontId = presetInfo.soundFontId
      state.loadedPresetIndex = presetInfo.presetIndex
      return firstTime ? .none : playNote(state, audioUnit: audioUnit)
    }

    return .none
  }

  func playNote(_ state: State, audioUnit: SF2LibAU) -> Effect<Action> {
    @Shared(.playSoundOnPresetChange) var playSoundOnPresetChange
    guard playSoundOnPresetChange else { return .none }
    return .run { _ in
      // Play a short note using the new preset
      _ = audioUnit.sendNoteOn(note: 60)
      try await Task.sleep(for: .milliseconds(1000))
      _ = audioUnit.sendNoteOff(note: 60)
    }.cancellable(id: CancelId.playSample, cancelInFlight: true)
  }

  func initialize(_ state: inout State) -> Effect<Action> {
    let engine = state.engine
    state.observers.append(
      NotificationCenter.default
        .addObserver(
          forName: AVAudioSession.mediaServicesWereResetNotification,
          object: nil,
          queue: nil
        ) { _ in
          self.restartAudioSession(engine: engine)
        }
    )
    return .merge(
      createSynth(&state),
      monitorActivePresetId(&state),
      monitorRouteChanged(&state)
    )
  }

  func createSynth(_ state: inout State) -> Effect<Action> {
    .run { send in
      let acd: AudioComponentDescription = .init(
        componentType: FourCharCode(stringLiteral: "aumu"),
        componentSubType: FourCharCode(stringLiteral: "Sf2L"),
        componentManufacturer: FourCharCode(stringLiteral: "BRay"),
        componentFlags: 0,
        componentFlagsMask: 0
      )

      AUAudioUnit.registerSubclass(SF2LibAU.self, as: acd, name: "SF2LibAU", version: 1)
      let avAudioUnit = try await AVAudioUnit.instantiate(with: acd, options: [])
      await send(.useAudioUnit(avAudioUnit))
    }.cancellable(id: CancelId.createSynth, cancelInFlight: true)
  }

  func useAudioUnit(_ state: inout State, audioUnit: AVAudioUnit) -> Effect<Action> {
    if let audioFormat = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: sampleRate,
      channels: 2,
      interleaved: false
    ) {
      state.avAudioUnit = audioUnit

      if let avMIDIInstrument = state.midiSynth,
         let au = state.audioUnit {
        state.engine.attach(avMIDIInstrument)
        state.engine.connect(avMIDIInstrument, to: state.engine.outputNode, format: audioFormat)
        startAudioSession(engine: state.engine)
        return .merge(
          .send(.activePresetIdChanged),
          .send(.delegate(.activeSynth(au, avMIDIInstrument)))
        )
      }
    }

    return .none
  }

  func startAudioSession(engine: AVAudioEngine) {
    log.debug("startAudioSession BEGIN")

    let sampleRate: Double = 44100.0
    let bufferSize: Int = 64
    let session = AVAudioSession.sharedInstance()

    do {
      log.debug("startAudioSession - setting AudioSession category")
      try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      log.debug("startAudioSession - done")
    } catch let error as NSError {
      log.error(
        "startAudioSession - failed to set the audio session category and mode: \(error.localizedDescription)"
      )
    }

    log.debug("startAudioSession - sampleRate: \(AVAudioSession.sharedInstance().sampleRate)")
    log.debug("startAudioSession - preferredSampleRate: \(AVAudioSession.sharedInstance().sampleRate)")

    do {
      log.debug("startAudioSession - setting sample rate")
      try session.setPreferredSampleRate(sampleRate)
      log.debug("startAudioSession - done")
    } catch let error as NSError {
      log.error("startAudioSession - failed to set the preferred sample rate to \(sampleRate) - \(error.localizedDescription)")
    }

    do {
      log.debug("startAudioSession - setting IO buffer duration")
      try session.setPreferredIOBufferDuration(Double(bufferSize) / sampleRate)
      log.debug("startAudioSession - done")
    } catch let error as NSError {
      log.error("startAudioSession - failed to set the preferred buffer size to \(bufferSize) - \(error.localizedDescription)")
    }

    do {
      log.debug("startAudioSession - setting active audio session")
      try session.setActive(true, options: [])
      log.debug("startAudioSession - done")
    } catch {
      log.error("startAudioSession - failed to set active - \(error.localizedDescription)")
    }

    do {
      log.debug("startAudioSession - starting engine")
      try engine.start()
    } catch {
      log.error("startAudioSession - failed to start - \(error.localizedDescription)")
    }

    dump(route: session.currentRoute)
  }

  /**
   Stop audio processing. This is only done if background running is disabled and then just before the app moves into
   the background.
   */
  func stopAudioSession(engine: AVAudioEngine) {
    log.debug("stopAudioSession BEGIN")

    engine.stop()

    let session = AVAudioSession.sharedInstance()
    do {
      log.debug("stopAudio - setting AudioSession to inactive")
      try session.setActive(false, options: [])
      log.debug("stopAudio - done")
    } catch let error as NSError {
      log.error("stopAudio - Failed session.setActive(false): \(error.localizedDescription)")
    }

    log.debug("stopAudio END")
  }

  func restartAudioSession(engine: AVAudioEngine) {
    log.error("recreateSynth - BEGIN")
    stopAudioSession(engine: engine)
    startAudioSession(engine: engine)
    log.error("recreateSynth - END")
  }

  func monitorActivePresetId(_ state: inout State) -> Effect<Action> {
    .publisher {
      $activeState.activePresetId
        .publisher
        .map { _ in .activePresetIdChanged }
    }.cancellable(id: CancelId.monitorActivePresetId, cancelInFlight: true)
  }

  func monitorRouteChanged(_ state: inout State) -> Effect<Action> {
    .publisher {
      NotificationCenter.default
        .publisher(for: AVAudioSession.routeChangeNotification)
        .map { _ in .routeChanged }
    }.cancellable(id: CancelId.monitorRouteChanged, cancelInFlight: true)
  }

  func routeChanged(_ state: inout State) -> Effect<Action> {
    let bufferSize: Int = 64
    let session = AVAudioSession.sharedInstance()

    do {
      log.debug("startAudioSessionInBackground - setting AudioSession category")
      try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      log.debug("startAudioSessionInBackground - done")
    } catch let error as NSError {
      let err = error.localizedDescription
      log.error("startAudioSessionInBackground - failed to set the audio session category and mode: \(err)")
    }

    log.debug("startAudioSessionInBackground - sampleRate: \(AVAudioSession.sharedInstance().sampleRate)")
    log.debug("startAudioSessionInBackground - preferredSampleRate: \(AVAudioSession.sharedInstance().sampleRate)")

    do {
      log.debug("startAudioSessionInBackground - setting sample rate")
      try session.setPreferredSampleRate(sampleRate)
      log.debug("startAudioSessionInBackground - done")
    } catch let error as NSError {
      let err = error.localizedDescription
      log.error("startAudioSessionInBackground - failed to set the preferred sample rate to \(sampleRate) - \(err)")
    }

    do {
      log.debug("startAudioSessionInBackground - setting IO buffer duration")
      try session.setPreferredIOBufferDuration(Double(bufferSize) / sampleRate)
      log.debug("startAudioSessionInBackground - done")
    } catch let error as NSError {
      let err = error.localizedDescription
      log.error("startAudioSessionInBackground - failed to set the preferred buffer size to \(bufferSize) - \(err)")
    }

    do {
      log.debug("startAudioSessionInBackground - setting active audio session")
      try session.setActive(true, options: [])
      log.debug("startAudioSessionInBackground - done")
    } catch {
      let err = error.localizedDescription
      log.error("startAudioSessionInBackground - failed to set active - \(err)")
    }

    dump(route: session.currentRoute)

    log.debug("startAudioSessionInBackground - starting synth")

    return .none
  }
}

private func dump(route: AVAudioSessionRouteDescription) {
  for input in route.inputs {
    log.debug("AVAudioSession input - \(input.portName)")
  }
  for output in route.outputs {
    log.debug("AVAudioSession output - \(output.portName)")
  }
}
