// Copyright © 2025 Brad Howes. All rights reserved.

import AudioToolbox
import BaseSupport
import ComposableArchitecture
import CoreAudioKit
import Dependencies
import Engine
import Models
import os
import SF2LibAU
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
    case playNote
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

  static var playNoteDurationMilliseconds: Duration { .milliseconds(500) }

  @Dependency(\.audioGraph) private var audioGraph
  @Dependency(\.audioSession) private var audioSession
  @Dependency(\.defaultDatabase) private var database
  @Dependency(\.synthAUv3ComponentDescription) private var synthAUv3ComponentDescription

  @Shared(.appActiveState) private var activeState
  @Shared(.backgroundProcessing) private var backgroundProcessing
  @Shared(.playSoundOnPresetChange) var playSoundOnPresetChange
  @Shared(.avAudioUnit) private var synth

  public var body: some ReducerOf<Self> {

    Reduce { state, action in

      log.info("reduce \(action)")

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

      case .playNote:
        return playNote(state)

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
    startAudioSession(&state)
    log.info("acquireAudioSession - END")
    return .none
  }

  private func beginMonitoring(_ state: inout State) -> Effect<Action> {
    log.info("beginMonitoring - BEGIN")
    // Start up the monitors now that we have a synth and signal Root that it is running
    return .merge(
      monitorActivePresetId(&state),
      monitorMediaServices(&state),
      monitorRouteChanged(&state),
      monitorLastLoadFinished(&state),
      .send(.delegate(.running))
    )
  }

  private func createSynthAudioUnit(_ state: inout State) -> Effect<Action> {
    log.info("createSynth")
    return .run { [synthAUv3ComponentDescription = synthAUv3ComponentDescription] send in
      log.info("createSynth - instantiating audio unit")
      let sau = try await SF2LibAU.create(synthAUv3ComponentDescription)
      log.debug("createSynth - synth: \(sau.description)")
      await send(.synthAudioUnitCreated(sau))
    }.cancellable(id: CancelId.createSynth, cancelInFlight: true)
  }

  private func createSynthAudioUnitDone(_ state: inout State, synth: AVAudioUnit) -> Effect<Action> {
    log.info("createSynthAudioUnitDone BEGIN")

    $synth.withLock { $0 = synth }

    @Shared(.auAudioUnit) var auAudioUnit
    $auAudioUnit.withLock { $0 = synth.auAudioUnit }

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
    audioGraph.stop()
    log.info("destroyAudioGraph END")
  }

  private func initialize(_ state: inout State) -> Effect<Action> {
    log.info("initialize")
    return createSynthAudioUnit(&state)
  }

  private func lastPresetLoadFinished(_ state: inout State) -> Effect<Action> {
    log.info("lastPresetLoadFinished BEGIN - \(state.firstTimePresetLoaded)")
    guard
      let parameterTree = synth?.parameterTree,
      let presetId = activeState.activePresetId
    else {
      return .none
    }

    if let audioConfig = AudioConfig.with(presetId: presetId) {
      let gainAddress = AUParameterAddress(SF2.Entity.Generator.Index.initialAttenuation.rawValue)
      let gainParameter = parameterTree.parameter(withAddress: gainAddress)
      gainParameter?.setValue(audioConfig.gain.gainGeneratorValue, originator: nil)

      let panAddress = AUParameterAddress(SF2.Entity.Generator.Index.pan.rawValue)
      let panParameter = parameterTree.parameter(withAddress: panAddress)
      panParameter?.setValue(audioConfig.pan.panGeneratorValue, originator: nil)
    }

    let firstTimePresetLoaded = state.firstTimePresetLoaded
    state.firstTimePresetLoaded = false
    return firstTimePresetLoaded ? .none : playNote(state)
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
    guard let parameterTree = synth?.parameterTree else {
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

  private func playNote(_ state: State) -> Effect<Action> {
    log.debug("playNote BEGIN - \(playSoundOnPresetChange) ")

    guard let synth = synth?.synth else {
      log.debug("playNote END - !synth")
      return .none
    }

    guard playSoundOnPresetChange else {
      log.debug("playNote END - !playSoundOnPresetChange")
      return .none
    }

    return .run { _ in
      @Dependency(\.continuousClock) var clock
      log.debug("sending note on")
      synth.sendNoteOn(note: 60)
      try? await clock.sleep(for: Self.playNoteDurationMilliseconds)
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
    log.info("startAudioSession BEGIN - \(state.audioSessionActivated)")
    if !state.audioSessionActivated {
      state.audioSessionActivated = audioSession.start(audioFormat)
      if state.audioSessionActivated {
        startEngine(&state)
      }
    }
    log.info("startAudioSession END - \(state.audioSessionActivated)")
  }

  private func startEngine(_ state: inout State) {
    log.info("startEngine BEGIN")
    let started = audioGraph.start(audioFormat)
    log.info("startEngine END - \(started)")
  }

  private func stopAudioSession(_ state: inout State) {
    log.info("stopAudioSession BEGIN")
    destroyAudioGraph(&state)
    audioSession.stop()
    state.audioSessionActivated = false
    log.info("stopAudioSession END")
  }

  private func useActivePreset(_ state: inout State, presetId: Preset.ID?) -> Effect<Action> {
    log.info("useActivePreset BEGIN - presetId: \(presetId ?? -1)")
    guard
      let synth = synth?.synth,
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
      return playNote(state)
    }

    let result: Bool
    if presetInfo.soundFontId == state.loadedSoundFontId {
      log.info("useActivePreset - loading preset \(presetInfo.presetIndex) \(presetInfo.presetName)")
      result = synth.sendUsePreset(preset: presetInfo.presetIndex, gain: 0.0, pan: 0.0)
    } else {
      guard let location = try? SoundFontKind(
        kind: presetInfo.kind,
        location: presetInfo.location,
        displayName: presetInfo.soundFontName
      )
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
