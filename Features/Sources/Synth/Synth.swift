// Copyright © 2025 Brad Howes. All rights reserved.

import AudioToolbox
import AUv3Controls
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

private let log: Logger = .init(category: "Synth")

/**
 Manages the audio session and synth creation for the app. Not used by the AUv3 extension.
 */
@Reducer
public struct Synth {

  @ObservableState
  public struct State: Equatable {
    public var loadedSoundFontId: SoundFont.ID?
    public var loadedPresetIndex: Int?
    public var activePresetId: Preset.ID?

    @ObservationStateIgnored
    public var firstTimePresetLoaded: Bool = true
    @ObservationStateIgnored
    public var audioSessionActivated: Bool = false
    @ObservationStateIgnored
    public var avAudioUnit: AVAudioUnitMIDIInstrument?

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
    case synthAudioUnitCreated(AVAudioUnitMIDIInstrument)
    case synthAudioUnitCreationFailed

    @CasePathable
    public enum Delegate: Equatable {
      case audioUnitCreated(AVAudioUnitMIDIInstrument)
      case missingPresetInfo(Preset.ID)
      case running
      case stopped
    }
  }

  public init() {}

  public static var playNoteDurationMilliseconds: Duration { .milliseconds(500) }

  @Dependency(\.audioGraph) private var audioGraph
  @Dependency(\.audioSession) private var audioSession
  @Dependency(\.defaultDatabase) private var database
  @Dependency(\.avAudioUnitMIDIInstrumentGenerator) private var avAudioUnitGen

  @Shared(.backgroundProcessing) private var backgroundProcessing
  @Shared(.playSoundOnPresetChange) private var playSoundOnPresetChange

  public var body: some ReducerOf<Self> {

    Reduce { state, action in

      log.action("Synth", action)

      switch action {

      case .acquireAudioSession:
        return acquireAudioSession(&state)

      case .activePresetIdChanged(let presetId):
        return activePresetIdChanged(&state, presetId: presetId)

      case .audioSessionRouteChanged:
        return audioSessionRouteChanged(&state)

      case .deinitialize:
        return .merge(CancelId.allCases.map { .cancel(id: $0) })

      case .delegate:
        return .none

      case .initialize:
        return createSynthAudioUnit(&state)

      case .lastPresetLoadFinished:
        return lastPresetLoadFinished(&state)

      case .mediaServicesWereReset:
        return restartAudioSession(&state)

      case .playNote:
        return sendNoteOnOffSequence(state)

      case .releaseAudioSession:
        return releaseAudioSession(&state)

      case .synthAudioUnitCreated(let avAudioUnit):
        return createSynthAudioUnitDone(&state, avAudioUnit: avAudioUnit)

      case .synthAudioUnitCreationFailed:
        log.error("Failed to create AVAudioUnit")
        return .none
      }
    }
  }

  private enum CancelId: String, CaseIterable {
    case synthCreateSynth
    case synthMonitorLastLoadFinished
    case synthMonitorMediaServices
    case synthMonitorRouteChanged
    case synthPlayNote
  }
}

extension Synth {

  private func activePresetIdChanged(_ state: inout State, presetId: Preset.ID?) -> Effect<Action> {
    log.info("activePresetIdChanged BEGIN - presetId: \(presetId ?? -1)")
    guard
      let presetId = presetId
    else {
      log.info("activePresetIdChanged END - nil preset ID")
      return .none
    }

    guard
      let avAudioUnit = state.avAudioUnit,
      state.audioSessionActivated
    else {
      log.info("activePresetIdChanged END - nil audioUnit or inactive audio session")
      return .none
    }

    guard let presetInfo = PresetLoadingInfo.for(id: presetId) else {
      log.info("activePresetIdChanged END - no presetInfo")
      return .none
    }

    state.activePresetId = presetId

    guard state.loadedPresetIndex != presetInfo.presetIndex || state.loadedSoundFontId != presetInfo.soundFontId else {
      log.info("activePresetIdChanged END - already loaded")
      return sendNoteOnOffSequence(state)
    }

    let sentRequest: Bool
    if presetInfo.soundFontId == state.loadedSoundFontId {
      log.info("activePresetIdChanged - loading preset \(presetInfo.presetIndex) \(presetInfo.presetName)")
      sentRequest = avAudioUnit.sendUsePreset(preset: presetInfo.presetIndex, gain: 0.0, pan: 0.0)
    } else {
      sentRequest = sendLoadFileUsePreset(avAudioUnit, presetInfo: presetInfo)
    }

    state.loadedPresetIndex = presetInfo.presetIndex
    state.loadedSoundFontId = presetInfo.soundFontId

    log.info("activePresetIdChanged END - \(sentRequest)")
    return .none
  }

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
    var actions = [
      .send(.delegate(.running)),
      monitorLastLoadFinished(&state)
    ]

#if os(iOS)
    actions.append(contentsOf: [
      monitorMediaServices(&state),
      monitorRouteChanged(&state)
    ])
#endif // os(iOS)

    // Start up the monitors now that we have a synth and signal Root that it is running
    return .merge(actions)
  }

  private func createSynthAudioUnit(_ state: inout State) -> Effect<Action> {
    log.info("createSynth")
    return .run(priority: .utility, name: "createSynthAudioUnit") { [avAudioUnitGen] send in
      log.info("createSynth - instantiating audio unit")
      if let avAudioUnit = await avAudioUnitGen.generate() {
        log.debug("createSynth - synth: \(avAudioUnit.description)")
        await send(.synthAudioUnitCreated(avAudioUnit))
      } else {
        log.debug("failed to cast AVAudioUnit to AVAudioUnitMIDIInstrument")
        await send(.synthAudioUnitCreationFailed)
      }
    }.cancellable(id: CancelId.synthCreateSynth, cancelInFlight: true)
  }

  private func createSynthAudioUnitDone(_ state: inout State, avAudioUnit: AVAudioUnitMIDIInstrument) -> Effect<Action> {
    log.info("createSynthAudioUnitDone BEGIN")

    state.avAudioUnit = avAudioUnit

    if state.audioSessionActivated {
      startEngine(&state)
    } else {
      startAudioSession(&state)
    }

    log.info("createSynthAudioUnitDone END")
    return .concatenate(
      .send(.delegate(.audioUnitCreated(avAudioUnit))),
      beginMonitoring(&state)
    )
  }

  private func destroyAudioGraph(_ state: inout State) {
    log.info("destroyAudioGraph BEGIN")
    if let midiInstrument = state.avAudioUnit?.midiInstrument {
      audioGraph.stop(audioGraph.engine, midiInstrument)
    }
    log.info("destroyAudioGraph END")
  }

  private func lastPresetLoadFinished(_ state: inout State) -> Effect<Action> {
    let firstTimePresetLoaded = state.firstTimePresetLoaded
    log.info("lastPresetLoadFinished BEGIN - \(firstTimePresetLoaded)")

    guard
      let parameterTree = state.avAudioUnit?.parameterTree,
      let presetId = state.activePresetId
    else {
      log.info("lastPresetLoadFinished END - nil parameterTree or presetId")
      return .none
    }

    if let audioConfig = AudioConfig.with(presetId: presetId) {
      let gainAddress = AUParameterAddress(SF2.Entity.Generator.Index.initialAttenuation.rawValue)
      let gainParameter = parameterTree.parameter(withAddress: gainAddress)
      unsafe gainParameter?.setValue(audioConfig.gain.gainGeneratorValue, originator: nil)

      let panAddress = AUParameterAddress(SF2.Entity.Generator.Index.pan.rawValue)
      let panParameter = parameterTree.parameter(withAddress: panAddress)
      unsafe panParameter?.setValue(audioConfig.pan.panGeneratorValue, originator: nil)
    }

    state.firstTimePresetLoaded = false

    log.info("lastPresetLoadFinished END")
    return firstTimePresetLoaded ? .none : sendNoteOnOffSequence(state)
  }

  private func monitorLastLoadFinished(_ state: inout State) -> Effect<Action> {
    log.info("monitorLastLoadFinished BEGIN")
    guard let parameterTree = state.avAudioUnit?.parameterTree else {
      fatalError("monitorLastLoadFinished - unexpected nil parameterTree chain")
    }

    guard
      let parameter = parameterTree.parameter(withAddress: SF2.Render.Engine.ParameterAddress.lastLoadFinished.rawValue)
    else {
      fatalError("monitorLastLoadFinished - did not find lastLoadFinished parameter")
    }

    return .run(priority: .utility, name: "monitorLastLoadFinished") { send in
      let stream: AsyncStream<AUValue>
      let observerToken: AUParameterObserverToken
      unsafe (observerToken, stream) = parameter.startObserving()

      defer {
        unsafe parameter.removeParameterObserver(observerToken)
        log.debug("monitorLastLoadFinished - stopped task")
      }
      if Task.isCancelled { return }
      for await _ in stream {
        if Task.isCancelled { break }
        await send(.lastPresetLoadFinished)
      }
    }.cancellable(id: CancelId.synthMonitorLastLoadFinished, cancelInFlight: true)
  }

#if os(iOS)

  private func monitorMediaServices(_ state: inout State) -> Effect<Action> {
    log.info("monitorMediaServices BEGIN")
    return .run { send in
      for await _ in NotificationCenter.default.notifications(named: AVAudioSession.mediaServicesWereResetNotification) {
        log.debug("monitorMediaServices - mediaServicesWereResetNotification fired")
        await send(.mediaServicesWereReset)
      }
    }.cancellable(id: CancelId.synthMonitorMediaServices, cancelInFlight: true)
  }

  private func monitorRouteChanged(_ state: inout State) -> Effect<Action> {
    log.info("monitorRouteChanged BEGIN")
    return .run { send in
      for await _ in NotificationCenter.default.notifications(named: AVAudioSession.routeChangeNotification) {
        log.debug("monitorMediaServices - routeChangeNotification fired")
        await send(.audioSessionRouteChanged)
      }
    }.cancellable(id: CancelId.synthMonitorRouteChanged, cancelInFlight: true)
  }

#endif // os(iOS)

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

  private func sendLoadFileUsePreset(_ avAudioUnit: AVAudioUnitMIDIInstrument, presetInfo: PresetLoadingInfo) -> Bool {
    log.info("sendLoadFileUsePreset BEGIN - \(presetInfo, privacy: .public)")

    guard
      let location = try? SoundFontKind(
        kind: presetInfo.kind,
        location: presetInfo.location,
        displayName: presetInfo.soundFontName,
      )
    else {
      log.error("sendLoadFileUsePreset END - unexpected nil location for \(presetInfo, privacy: .public)")
      return false
    }

    if case let .external(bookmark) = location {
      guard let data = bookmark.bookmark else {
        log.error("sendLoadFileUsePreset END - unexpected nil bookmark data for \(presetInfo, privacy: .public)")
        return false
      }

      log.debug("sending bookmark data to synth - \(bookmark.url, privacy: .public)")

      return avAudioUnit.sendLoadBookmarkUsePreset(
        bookmark: data,
        preset: presetInfo.presetIndex,
        gain: presetInfo.gain,
        pan: presetInfo.pan
      )

    } else {
      log.debug("sending file path to synth - \(location.url, privacy: .public)")
      return avAudioUnit.sendLoadFileUsePreset(
        path: location.url.path(percentEncoded: false),
        preset: presetInfo.presetIndex,
        gain: presetInfo.gain,
        pan: presetInfo.pan
      )
    }
  }

  private func sendNoteOnOffSequence(_ state: State) -> Effect<Action> {
    log.debug("playNote BEGIN - \(playSoundOnPresetChange) ")

    guard let avAudioUnit = state.avAudioUnit else {
      log.debug("playNote END - !avAudioUnit")
      return .none
    }

    guard playSoundOnPresetChange else {
      log.debug("playNote END - !playSoundOnPresetChange")
      return .none
    }

    return .run(priority: .utility, name: "playNote") { _ in
      @Dependency(\.continuousClock) var clock
      log.debug("sending note on")
      avAudioUnit.startNote(60, withVelocity: 127, onChannel: 0)
      try? await clock.sleep(for: Self.playNoteDurationMilliseconds)
      log.debug("sending note off")
      avAudioUnit.stopNote(60, onChannel: 0)
    }.cancellable(id: CancelId.synthPlayNote, cancelInFlight: true)
  }

  private func startAudioSession(_ state: inout State) {
    var audioSessionActivated = state.audioSessionActivated
    log.info("startAudioSession BEGIN - \(audioSessionActivated)")
    if !audioSessionActivated {
      audioSessionActivated = audioSession.start()
      state.audioSessionActivated = audioSessionActivated
      if audioSessionActivated {
        startEngine(&state)
      }
    }
    log.info("startAudioSession END - \(audioSessionActivated)")
  }

  private func startEngine(_ state: inout State) {
    log.info("startEngine BEGIN")
    guard let midiInstrument = state.avAudioUnit?.midiInstrument else {
      log.info("startEngine END - no midi instrument")
      return
    }

    let started = audioGraph.start(audioGraph.engine, midiInstrument)
    log.info("startEngine END - \(started)")
  }

  private func stopAudioSession(_ state: inout State) {
    log.info("stopAudioSession BEGIN")
    audioSession.stop()
    state.audioSessionActivated = false
    log.info("stopAudioSession END")
  }
}
