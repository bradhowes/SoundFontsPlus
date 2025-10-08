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
    var loadedSoundFontId: SoundFont.ID?
    var loadedPresetIndex: Int?
    var firstTimePresetLoaded: Bool = true

    @ObservationStateIgnored
    var sessionActive: Bool = false

    public init() {}
  }

  public enum Action {
    case activePresetIdChanged(Preset.ID?)
    case audioSessionRouteChanged
    case deinitialize
    case initialize
    case lastPresetLoadFinished
    case mediaServicesWereReset
    case sceneBecameActive
    case sceneBecameInactive
    case synthCreated
  }

  public init() {}

  // TODO: make into a dependency for testing
  private let engine = AVAudioEngine()

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
      print("synth action: ", action)
      switch action {

      case .activePresetIdChanged(let presetId):
        guard state.sessionActive else { return .none }
        return useActivePreset(&state, presetId: presetId)

      case .audioSessionRouteChanged:
        return audioSessionRouteChanged(&state)

      case .deinitialize:
        return .merge(CancelId.allCases.map { .cancel(id: $0) })

      case .initialize:
        return initialize(&state)

      case .lastPresetLoadFinished:
        return lastPresetLoadFinished(&state)

      case .mediaServicesWereReset:
        return restartAudioSession(&state)

      case .sceneBecameActive:
        return sceneBecameActive(&state)

      case .sceneBecameInactive:
        return sceneBecameInactive(&state)

      case .synthCreated:
        return synthCreated(&state)
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
    return restartAudioSession(&state)
  }

  private func configureAudioSession() {
    let bufferSize: Int = 64

    do {
      log.info("routeChanged - setting AudioSession category")
      try audioSession.setCategory(.playback, .default, [.mixWithOthers])
    } catch let error as NSError {
      let err = error.localizedDescription
      log.error("routeChanged - failed to set the audio session category and mode: \(err)")
    }

    log.info("routeChanged - sampleRate: \(audioSession.sampleRate())")

    do {
      log.info("routeChanged - setting preferred sample rate")
      try audioSession.setPreferredSampleRate(audioFormat.sampleRate)
    } catch let error as NSError {
      let err = error.localizedDescription
      log.error("routeChanged - failed to set the preferred sample rate to \(audioFormat.sampleRate) - \(err)")
    }

    let bufferDuration = Double(bufferSize) / audioFormat.sampleRate
    do {
      log.info("routeChanged - setting IO buffer duration \(bufferDuration)")
      try audioSession.setPreferredIOBufferDuration(bufferDuration)
    } catch let error as NSError {
      let err = error.localizedDescription
      log.error("routeChanged - failed to set the preferred buffer size to \(bufferSize) - \(err)")
    }

    audioSession.currentRoute().dump()
  }

  private func createAudioChain(_ state: inout State) -> Bool {
    log.info("createAudioChain BEGIN")
    @Shared(.delayEffect) var delayEffect
    @Shared(.reverbEffect) var reverbEffect

    guard let synthAudioUnit, let delayEffect, let reverbEffect else {
      log.info("createAudioChain - no synth, delay, or reverb available")
      return false
    }

    if engine.isRunning {
      engine.stop()
    }

    log.info("createAudioChain - attaching to engine")
    engine.attach(synthAudioUnit)
    engine.attach(delayEffect)
    engine.attach(reverbEffect)

    log.info("createAudioChain - connecting audio units")
    engine.connect(reverbEffect, to: engine.outputNode, format: audioFormat)
    engine.connect(delayEffect, to: reverbEffect, format: audioFormat)
    engine.connect(synthAudioUnit, to: delayEffect, format: audioFormat)

    log.info("createAudioChain END")
    return true
  }

  private func createSynth(_ state: inout State) -> Effect<Action> {
    log.info("createSynth")
    return .run { send in
      let acd: AudioComponentDescription = .init(
        componentType: FourCharCode(stringLiteral: "aumu"),
        componentSubType: FourCharCode(stringLiteral: "Sf2L"),
        componentManufacturer: FourCharCode(stringLiteral: "BRay"),
        componentFlags: 0,
        componentFlagsMask: 0
      )

      AUAudioUnit.registerSubclass(SF2LibAU.self, as: acd, name: "SF2LibAU", version: 1)

      log.info("createSynth - instantiating audio unit")
      let sau = try await AVAudioUnit.instantiate(with: acd, options: [])

      @Shared(.synthAudioUnit) var synthAudioUnit
      $synthAudioUnit.withLock { $0 = sau }

      log.info("createSynth - created")
      await send(.synthCreated)
    }.cancellable(id: CancelId.createSynth, cancelInFlight: true)
  }

  private func destroyAudioChain(_ state: inout State) {
    log.info("destroyAudioChain BEGIN")
    @Shared(.delayEffect) var delayEffect
    @Shared(.reverbEffect) var reverbEffect

    log.info("destroyAudioChain - resetting synth")
    synthAudioUnit?.reset()
    log.info("destroyAudioChain - stopping engine")
    engine.stop()

    if let delay = delayEffect {
      log.info("destroyAudioChain - detaching delay")
      engine.detach(delay)
    }

    if let reverb = reverbEffect {
      log.info("destroyAudioChain - detaching reverb")
      engine.detach(reverb)
    }

    if let synth = synthAudioUnit {
      log.info("destroyAudioChain - detaching synth")
      engine.detach(synth)
      $synthAudioUnit.withLock { $0 = nil }
    }

    log.info("destroyAudioChain END")
  }

  private func initialize(_ state: inout State) -> Effect<Action> {
    log.info("initialize")
    return .concatenate(
      createSynth(&state),
      .merge(
        monitorActivePresetId(&state),
        monitorMediaServices(&state),
        monitorRouteChanged(&state),
      )
    )
  }

  private func lastPresetLoadFinished(_ state: inout State) -> Effect<Action> {
    log.info("lastPresetLoadFinished - \(state.firstTimePresetLoaded)")

    guard let synthAudioUnit = synthAudioUnit?.synth else {
      return .none
    }

    let firstTimePresetLoaded = state.firstTimePresetLoaded
    state.firstTimePresetLoaded = false

    return firstTimePresetLoaded ? .none : playNote(state, synth: synthAudioUnit)
  }

  private func monitorActivePresetId(_ state: inout State) -> Effect<Action> {
    .publisher {
      $activeState.activePresetId
        .publisher
        .removeDuplicates()
        .map { value in .activePresetIdChanged(value) }
    }.cancellable(id: CancelId.monitorActivePresetId, cancelInFlight: true)
  }

  private func monitorLastLoadFinished(_ state: inout State) -> Effect<Action> {
    guard let parameterTree = synthAudioUnit?.auAudioUnit.parameterTree else {
      fatalError("unexpected nil parameterTree chain")
    }

    guard
      let parameter = parameterTree.parameter(withAddress: SF2.Render.Engine.ParameterAddress.lastLoadFinished.rawValue)
    else {
      fatalError("did not find lastLoadFinished parameter")
    }

    return .publisher {
      parameter.publisher(for: \.value)
        .buffer(size: 1, prefetch: .byRequest, whenFull: .dropOldest)
        .filter { $0 > 0.0 }
        .map { _ in
          .lastPresetLoadFinished
        }
    }.cancellable(id: CancelId.monitorLastLoadFinished)
  }

  private func monitorMediaServices(_ state: inout State) -> Effect<Action> {
    .publisher {
      NotificationCenter.default
        .publisher(for: AVAudioSession.mediaServicesWereResetNotification)
        .map { _ in .mediaServicesWereReset }
    }.cancellable(id: CancelId.monitorMediaServices, cancelInFlight: true)
  }

  private func monitorRouteChanged(_ state: inout State) -> Effect<Action> {
    .publisher {
      NotificationCenter.default
        .publisher(for: AVAudioSession.routeChangeNotification)
        .map { _ in .audioSessionRouteChanged }
    }.cancellable(id: CancelId.monitorRouteChanged, cancelInFlight: true)
  }

  private func playNote(_ state: State, synth: SF2LibAU) -> Effect<Action> {
    @Shared(.playSoundOnPresetChange) var playSoundOnPresetChange
    guard playSoundOnPresetChange else { return .none }
    return .run { _ in
      @Dependency(\.continuousClock) var clock
      synth.sendNoteOn(note: 60)
      try? await clock.sleep(for: .milliseconds(250))
      synth.sendNoteOff(note: 60)
    }.cancellable(id: CancelId.playNote, cancelInFlight: true)
  }

  private func restartAudioSession(_ state: inout State) -> Effect<Action> {
    log.info("restartAudioSession - BEGIN")
    stopAudioSession(&state)
    startAudioSession(&state)
    log.info("recreateSynth - END")
    return .none
  }

  private func sceneBecameActive(_ state: inout State) -> Effect<Action> {
    if !state.sessionActive {
      startAudioSession(&state)
    }
    return .none
  }

  private func sceneBecameInactive(_ state: inout State) -> Effect<Action> {
    if !backgroundProcessing {
      stopAudioSession(&state)
    }
    return .none
  }

  private func startAudioSession(_ state: inout State) {
    log.info("startAudioSession BEGIN")

    configureAudioSession()

    do {
      log.info("routeChanged - setting active audio session")
      try audioSession.setActive(true, [])
      state.sessionActive = true
    } catch {
      let err = error.localizedDescription
      log.error("routeChanged - failed to set active - \(err)")
    }

    if state.sessionActive && createAudioChain(&state) {
      startEngine(&state)
    }
  }

  private func startEngine(_ state: inout State) {
    guard !engine.isRunning else {
      log.info("startEngine - already running")
      return
    }

    do {
      log.info("startEngine - starting")
      try engine.start()
      log.info("startEngine - done")
    } catch {
      log.error("startAudioSession - failed to start - \(error.localizedDescription)")
    }
  }

  private func stopAudioSession(_ state: inout State) {
    log.info("stopAudioSession BEGIN")

    destroyAudioChain(&state)

    do {
      log.info("stopAudioSession - setting AudioSession to inactive")
      try audioSession.setActive(false, [.notifyOthersOnDeactivation])
      log.info("stopAudioSession - done")
    } catch let error as NSError {
      log.error("stopAudioSession - Failed session.setActive(false): \(error.localizedDescription)")
    }

    state.sessionActive = false

    log.info("stopAudioSession END")
  }

  private func synthCreated(_ state: inout State) -> Effect<Action> {
    log.info("synthCreated BEGIN")

    // There is a race between making the AVAudioSession active and having an synth audio unit. If the synth is
    // available first, then
    if state.sessionActive {
      if createAudioChain(&state) {
        startEngine(&state)
      }
    } else {
      startAudioSession(&state)
    }

    log.info("synthCreated END")
    return .concatenate(
      monitorLastLoadFinished(&state),
      useActivePreset(&state, presetId: activeState.activePresetId)
    )
  }

  private func useActivePreset(_ state: inout State, presetId: Preset.ID?) -> Effect<Action> {
    log.info("useActivePreset BEGIN")
    guard let synth = synthAudioUnit?.synth else {
      log.info("nil audioUnit -- ignoring")
      return .none
    }

    guard let presetInfo = Operations.presetLoadingInfo(id: presetId) else {
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
      result = synth.sendUsePreset(preset: presetInfo.presetIndex, gain: 0.0, pan: 0.0)
    } else {
      guard let location = try? SoundFontKind(kind: presetInfo.kind, location: presetInfo.location)
      else {
        log.error("unexpected nil location for \(presetInfo)")
        return .none
      }
      let path = location.path.path(percentEncoded: false)
      log.info("loading \(path) -- preset \(presetInfo.presetIndex) \(presetInfo.presetName)")
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
