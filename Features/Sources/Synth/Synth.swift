// Copyright © 2025 Brad Howes. All rights reserved.

import AudioToolbox
import BaseSupport
import ComposableArchitecture
import CoreAudioKit
import Dependencies
import Engine
import Models
import os
import Sharing
import SwiftUI

private let log = Logger(category: "Synth")

@Reducer
public struct Synth {

  @ObservableState
  public struct State: Equatable {
    public var loadedSoundFontId: SoundFont.ID?
    public var loadedPresetIndex: Int?

    @ObservationStateIgnored
    public let engine = AVAudioEngine()
    @ObservationStateIgnored
    public var firstTimePresetLoaded: Bool = true
    @ObservationStateIgnored
    public var audioSessionActivated: Bool = false

    public init(
      loadedSoundFontId: SoundFont.ID? = nil,
      loadedPresetIndex: Int? = nil,
      firstTimePresetLoaded: Bool = true,
      audioSessionActivated: Bool = false
    ) {
      self.loadedSoundFontId = loadedSoundFontId
      self.loadedPresetIndex = loadedPresetIndex
      self.firstTimePresetLoaded = firstTimePresetLoaded
      self.audioSessionActivated = audioSessionActivated
    }
  }

  public enum Action {
    case acquireAudioSession
    case activePresetIdChanged(Preset.ID?)
    case audioSessionRouteChanged
    case deinitialize
    case delegate(Delegate)
    case initialize
    case lastPresetLoadFinished
    case mediaServicesWereReset
    case releaseAudioSession
    case synthAudioUnitCreated(AVAudioUnit)

    public enum Delegate: Equatable {
      case running
      case stopped
    }
  }

  public init() {}

  private let audioFormat: AVAudioFormat! = AVAudioFormat(
    commonFormat: .pcmFormatFloat32,
    sampleRate: 48_000.0,
    channels: 2,
    interleaved: false
  )

  @Dependency(\.defaultDatabase) private var database
  @Dependency(\.audioSession) private var audioSession

  @Shared(.activeState) private var activeState
  @Shared(.backgroundProcessing) private var backgroundProcessing
  @Shared(.synthAudioUnit) private var synthAudioUnit

  public var body: some ReducerOf<Self> {

    Reduce { state, action in
      log.debug("reducer action: \(action)")

      switch action {

      case .acquireAudioSession:
        return acquireAudioSession(&state)

      case .activePresetIdChanged(let presetId):
        return useActivePreset(&state, presetId: presetId)

      case .audioSessionRouteChanged:
        return audioSessionRouteChanged(&state)

      case .deinitialize:
        return .merge(CancelId.allCases.map { .cancel(id: $0) })

      case .delegate:
        return .none

      case .initialize:
        return initialize(&state)

      case .lastPresetLoadFinished:
        return lastPresetLoadFinished(&state)

      case .mediaServicesWereReset:
        return restartAudioSession(&state)

      case .releaseAudioSession:
        return releaseAudioSession(&state)

      case .synthAudioUnitCreated(let audioUnit):
        return createSynthAudioUnitDone(&state, synth: audioUnit)
      }
    }
  }

  private enum CancelId: CaseIterable {
    case createSynth
    case monitorActivePresetId
    case monitorLastLoadFinished
    case monitorMediaServices
    case monitorRouteChanged
    case playNote
  }
}

extension Synth {

  private func audioSessionRouteChanged(_ state: inout State) -> Effect<Action> {
    log.info("audioSessionRouteChanged - BEGIN")
    return restartAudioSession(&state)
  }

  private func acquireAudioSession(_ state: inout State) -> Effect<Action> {
    log.info("acquireAudioSession - BEGIN")
    if !state.audioSessionActivated {
      startAudioSession(&state)
    }
    log.info("acquireAudioSession - END")
    return .none
  }

  private func beginMonitoring(_ state: inout State) -> Effect<Action> {
    log.info("beginMonitoring - BEGIN")
    // Start up the monitors now that we have a synth
    return .merge(
      monitorActivePresetId(&state),
      monitorMediaServices(&state),
      monitorRouteChanged(&state),
      monitorLastLoadFinished(&state),
      .send(.delegate(.running))
    )
  }

  private func configureAudioSession() {
    log.info("configureAudioSession - BEGIN")
    let bufferSize: Int = 64

    do {
      log.info("configureAudioSession - setting AudioSession category")
      try audioSession.setCategory(.playback, .default, [.mixWithOthers])
    } catch let error as NSError {
      let err = error.localizedDescription
      log.error("configureAudioSession - failed to set the audio session category and mode: \(err)")
    }

    log.info("configureAudioSession - sampleRate: \(audioSession.sampleRate())")

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

    audioSession.currentRoute().dump()
    log.info("configureAudioSession - END")
  }

  private func createSynthAudioUnit(_ state: inout State) -> Effect<Action> {
    log.info("createSynth")
    return .run { send in
      log.info("createSynth - instantiating audio unit")
      let sau = try await SF2LibAU.create()
      log.debug("createSynth - synth: \(sau.description)")
      await send(.synthAudioUnitCreated(sau))
    }.cancellable(id: CancelId.createSynth, cancelInFlight: true)
  }

  private func createSynthAudioUnitDone(_ state: inout State, synth: AVAudioUnit) -> Effect<Action> {
    log.info("createSynthAudioUnitDone BEGIN")

    $synthAudioUnit.withLock { $0 = synth }

    if state.audioSessionActivated {
      startEngine(&state)
    } else {
      startAudioSession(&state)
    }

    log.info("createSynthDone END")
    return beginMonitoring(&state)
  }

  private func destroyAudioGraph(_ state: inout State) {
    log.info("destroyAudioGraph BEGIN")
    @Shared(.delayEffect) var delayEffect
    @Shared(.reverbEffect) var reverbEffect

    log.info("destroyAudioGraph - resetting synth")
    synthAudioUnit?.reset()

    log.info("destroyAudioGraph - stopping engine")
    if state.engine.isRunning {
      state.engine.stop()
    }

    if let delay = delayEffect {
      log.info("destroyAudioGraph - detaching delay")
      state.engine.detach(delay)
    }

    if let reverb = reverbEffect {
      log.info("destroyAudioGraph - detaching reverb")
      state.engine.detach(reverb)
    }

    if let synth = synthAudioUnit {
      log.info("destroyAudioGraph - detaching synth")
      state.engine.detach(synth)
    }

    log.info("destroyAudioGraph END")
  }

  private func initialize(_ state: inout State) -> Effect<Action> {
    log.info("initialize")
    return createSynthAudioUnit(&state)
  }

  private func lastPresetLoadFinished(_ state: inout State) -> Effect<Action> {
    log.info("lastPresetLoadFinished BEGIN - \(state.firstTimePresetLoaded)")

    guard let synth = synthAudioUnit?.synth else {
      fatalError("lastPresetLoadFinished - unexpected nil synthAudioUnit")
    }

    let firstTimePresetLoaded = state.firstTimePresetLoaded
    state.firstTimePresetLoaded = false

    return firstTimePresetLoaded ? .none : playNote(state, synth: synth)
  }

  private func monitorActivePresetId(_ state: inout State) -> Effect<Action> {
    log.info("monitorActivePresetId BEGIN")
    return .publisher {
      $activeState.activePresetId
        .publisher
        .removeDuplicates()
        .map { value in
          log.debug("monitorActivePresetId activePresetId changed - \(String(describing: value))")
          return .activePresetIdChanged(value)
        }
    }.cancellable(id: CancelId.monitorActivePresetId, cancelInFlight: true)
  }

  private func monitorLastLoadFinished(_ state: inout State) -> Effect<Action> {
    log.info("monitorLastLoadFinished BEGIN")
    guard let parameterTree = synthAudioUnit?.auAudioUnit.parameterTree else {
      fatalError("monitorLastLoadFinished - unexpected nil parameterTree chain")
    }

    guard
      let parameter = parameterTree.parameter(withAddress: SF2.Render.Engine.ParameterAddress.lastLoadFinished.rawValue)
    else {
      fatalError("monitorLastLoadFinished - did not find lastLoadFinished parameter")
    }

    return .publisher {
      parameter.publisher(for: \.value)
        .buffer(size: 1, prefetch: .byRequest, whenFull: .dropOldest)
        .removeDuplicates()
        .filter { $0 > 0.0 }
        .map { lastLoadFinished in
          log.debug("monitorMediaServices lastLoadFinished value changed - \(lastLoadFinished)")
          return .lastPresetLoadFinished
        }
    }.cancellable(id: CancelId.monitorLastLoadFinished)
  }

  private func monitorMediaServices(_ state: inout State) -> Effect<Action> {
    log.info("monitorMediaServices BEGIN")
    return .publisher {
      NotificationCenter.default
        .publisher(for: AVAudioSession.mediaServicesWereResetNotification)
        .map { _ in
          log.debug("monitorMediaServices - mediaServicesWereResetNotification fired")
          return .mediaServicesWereReset
        }
    }.cancellable(id: CancelId.monitorMediaServices, cancelInFlight: true)
  }

  private func monitorRouteChanged(_ state: inout State) -> Effect<Action> {
    log.info("monitorRouteChanged BEGIN")
    return .publisher {
      NotificationCenter.default
        .publisher(for: AVAudioSession.routeChangeNotification)
        .map { _ in
          log.debug("monitorRouteChanged - routeChangeNotification fired")
          return .audioSessionRouteChanged
        }
    }.cancellable(id: CancelId.monitorRouteChanged, cancelInFlight: true)
  }

  private func playNote(_ state: State, synth: SF2LibAU) -> Effect<Action> {
    log.debug("playNote BEGIN")
    @Shared(.playSoundOnPresetChange) var playSoundOnPresetChange
    guard playSoundOnPresetChange else {
      log.debug("playNote END - !playSoundOnPresetChange")
      return .none
    }

    return .run { _ in
      @Dependency(\.continuousClock) var clock
      log.debug("sending note on")
      synth.sendNoteOn(note: 60)
      try? await clock.sleep(for: .milliseconds(250))
      log.debug("sending note off")
      synth.sendNoteOff(note: 60)
    }.cancellable(id: CancelId.playNote, cancelInFlight: true)
  }

  private func restartAudioSession(_ state: inout State) -> Effect<Action> {
    log.info("restartAudioSession - BEGIN")
    stopAudioSession(&state)
    startAudioSession(&state)
    log.info("restartAudioSession - END")
    return .none
  }

  private func releaseAudioSession(_ state: inout State) -> Effect<Action> {
    log.info("releaseAudioSession - BEGIN")
    if !backgroundProcessing {
      stopAudioSession(&state)
    }
    log.info("releaseAudioSession - END")
    return .none
  }

  private func startAudioSession(_ state: inout State) {
    log.info("startAudioSession BEGIN")
    precondition(!state.audioSessionActivated)

    configureAudioSession()

    do {
      log.info("startAudioSession - making audio session active")
      try audioSession.setActive(true, [])
      state.audioSessionActivated = true
    } catch {
      let err = error.localizedDescription
      log.error("startAudioSession - failed to set active - \(err)")
    }

    if state.audioSessionActivated {
      startEngine(&state)
    }
  }

  private func startEngine(_ state: inout State) {
    log.info("startEngine BEGIN")
    guard !state.engine.isRunning else {
      log.info("startEngine - already running")
      return
    }

    @Shared(.delayEffect) var delayEffect
    @Shared(.reverbEffect) var reverbEffect

    guard let synthAudioUnit, let delayEffect, let reverbEffect else {
      log.info("startEngine - no synth, delay, or reverb available")
      return
    }

    if state.engine.isRunning {
      log.info("startEngine - stopping engine")
      state.engine.stop()
    }

    log.info("startEngine - attaching audio units to engine")
    state.engine.attach(synthAudioUnit)
    state.engine.attach(delayEffect)
    state.engine.attach(reverbEffect)

    log.info("startEngine - connecting audio units together")
    state.engine.connect(reverbEffect, to: state.engine.outputNode, format: audioFormat)
    state.engine.connect(delayEffect, to: reverbEffect, format: audioFormat)
    state.engine.connect(synthAudioUnit, to: delayEffect, format: audioFormat)

    do {
      log.info("startEngine - starting")
      try state.engine.start()
    } catch {
      log.error("startEngine - failed to start - \(error.localizedDescription)")
    }

    log.info("startEngine END")
  }

  private func stopAudioSession(_ state: inout State) {
    log.info("stopAudioSession BEGIN")

    destroyAudioGraph(&state)

    do {
      log.info("stopAudioSession - deactivating AudioSession")
      try audioSession.setActive(false, [.notifyOthersOnDeactivation])
      log.info("stopAudioSession - done")
    } catch let error as NSError {
      log.error("stopAudioSession - Failed session.setActive(false): \(error.localizedDescription)")
    }

    state.audioSessionActivated = false

    log.info("stopAudioSession END")
  }

  private func useActivePreset(_ state: inout State, presetId: Preset.ID?) -> Effect<Action> {
    log.info("useActivePreset BEGIN - presetId: \(presetId ?? -1)")
    guard
      let synth = synthAudioUnit?.synth,
      state.audioSessionActivated
    else {
      log.info("useActivePreset END - nil audioUnit or inactive audio session")
      return .none
    }

    guard let presetInfo = Operations.presetLoadingInfo(id: presetId) else {
      log.info("useActivePreset END - no presetInfo")
      return .none
    }

    guard state.loadedPresetIndex != presetInfo.presetIndex || state.loadedSoundFontId != presetInfo.soundFontId else {
      log.info("useActivePreset END - already loaded")
      return .none
    }

    let result: Bool
    if presetInfo.soundFontId == state.loadedSoundFontId {
      log.info("useActivePreset - loading preset \(presetInfo.presetIndex) \(presetInfo.presetName)")
      result = synth.sendUsePreset(preset: presetInfo.presetIndex, gain: 0.0, pan: 0.0)
    } else {
      guard let location = try? SoundFontKind(kind: presetInfo.kind, location: presetInfo.location)
      else {
        log.error("useActivePreset END - unexpected nil location for \(presetInfo)")
        return .none
      }
      let path = location.path.path(percentEncoded: false)
      log.info("useActivePreset - loading \(path) -- preset \(presetInfo.presetIndex) \(presetInfo.presetName)")
      result = synth.sendLoadFileUsePreset(
        path: path,
        preset: presetInfo.presetIndex,
        gain: presetInfo.gain,
        pan: presetInfo.pan
      )
    }

    state.loadedPresetIndex = presetInfo.presetIndex
    state.loadedSoundFontId = presetInfo.soundFontId

    log.info("useActivePreset END - \(result)")
    return .none
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
