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

private let log = Logger(category: "Synth")

/**
 Manages the audio session and synth creation for the app. Not used by the AUv3 extension.
 */
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

  @Shared(.activeState) private var activeState
  @Shared(.backgroundProcessing) private var backgroundProcessing
  @Shared(.playSoundOnPresetChange) private var playSoundOnPresetChange

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
      monitorLastLoadFinished(&state)
    ]

#if os(iOS)
    actions.append(contentsOf: [
      monitorMediaServices(&state),
      monitorRouteChanged(&state)
    ])
#endif // os(iOS)

    actions.append(.send(.delegate(.running)))

    // Start up the monitors now that we have a synth and signal Root that it is running
    return .merge(actions)
  }

  private func createSynthAudioUnit(_ state: inout State) -> Effect<Action> {
    log.info("createSynth")
    return .run { [synthAUv3ComponentDescription] send in
      log.info("createSynth - instantiating audio unit")
      do {
        if let avAudioUnit = try await SF2LibAU.create(synthAUv3ComponentDescription) as? AVAudioUnitMIDIInstrument {
          log.debug("createSynth - synth: \(avAudioUnit.description)")
          await send(.synthAudioUnitCreated(avAudioUnit))
        } else {
          log.debug("failed to cast AVAudioUnit to AVAudioUnitMIDIInstrument")
          await send(.synthAudioUnitCreationFailed)
        }
      } catch {
        log.error("failed to create synth - \(error)")
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
    return .merge(
      .send(.delegate(.audioUnitCreated(avAudioUnit))),
      beginMonitoring(&state)
    )
  }

  private func destroyAudioGraph(_ state: inout State) {
    log.info("destroyAudioGraph BEGIN")
    if let midiInstrument = state.avAudioUnit?.midiInstrument {
      audioGraph.stop(midiInstrument)
    }
    log.info("destroyAudioGraph END")
  }

  private func initialize(_ state: inout State) -> Effect<Action> {
    log.info("initialize")
    return createSynthAudioUnit(&state)
  }

  private func lastPresetLoadFinished(_ state: inout State) -> Effect<Action> {
    log.info("lastPresetLoadFinished BEGIN - \(state.firstTimePresetLoaded)")
    guard
      let parameterTree = state.avAudioUnit?.parameterTree,
      let presetId = activeState.activePresetId
    else {
      log.info("lastPresetLoadFinished END - parameterTree: \(String(describing: state.avAudioUnit?.parameterTree))")
      log.info("lastPresetLoadFinished END - presetId: \(String(describing: activeState.activePresetId))")
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

    let firstTimePresetLoaded = state.firstTimePresetLoaded
    state.firstTimePresetLoaded = false

    log.info("lastPresetLoadFinished END")
    return firstTimePresetLoaded ? .none : playNote(state)
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

    let stream: AsyncStream<AUValue>
    let observerToken: AUParameterObserverToken
    unsafe (observerToken, stream) = parameter.startObserving()

    return .run { send in
      defer {
        unsafe parameter.removeParameterObserver(observerToken)
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
    return .publisher {
      NotificationCenter.default
        .publisher(for: AVAudioSession.mediaServicesWereResetNotification)
        .map { _ in
          log.debug("monitorMediaServices - mediaServicesWereResetNotification fired")
          return .mediaServicesWereReset
        }
    }.cancellable(id: CancelId.synthMonitorMediaServices, cancelInFlight: true)
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
    }.cancellable(id: CancelId.synthMonitorRouteChanged, cancelInFlight: true)
  }
#endif // os(iOS)

  private func playNote(_ state: State) -> Effect<Action> {
    log.debug("playNote BEGIN - \(playSoundOnPresetChange) ")

    guard let avAudioUnit = state.avAudioUnit else {
      log.debug("playNote END - !avAudioUnit")
      return .none
    }

    guard playSoundOnPresetChange else {
      log.debug("playNote END - !playSoundOnPresetChange")
      return .none
    }

    return .run { _ in
      @Dependency(\.continuousClock) var clock
      log.debug("sending note on")
      avAudioUnit.startNote(60, withVelocity: 127, onChannel: 0)
      try? await clock.sleep(for: Self.playNoteDurationMilliseconds)
      log.debug("sending note off")
      avAudioUnit.stopNote(60, onChannel: 0)
    }.cancellable(id: CancelId.synthPlayNote, cancelInFlight: true)
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
    guard let midiInstrument = state.avAudioUnit?.midiInstrument else {
      log.info("startEngine END - no midi instrument")
      return
    }

    let started = audioGraph.start(audioFormat, midiInstrument)
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
      let avAudioUnit = state.avAudioUnit,
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
      result = avAudioUnit.sendUsePreset(preset: presetInfo.presetIndex, gain: 0.0, pan: 0.0)
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
      result = avAudioUnit.sendLoadFileUsePreset(
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

extension AVAudioUnitMIDIInstrument {

  public func sendLoadFileUsePreset(path: String, preset: Int, gain: Double, pan: Double) -> Bool {
    sendMIDI(bytes: Array(SF2Engine.createLoadFileUsePresetPayload(std.string(path), preset)))
  }

  public func sendUsePreset(preset: Int, gain: Double, pan: Double) -> Bool {
    sendMIDI(bytes: Array(SF2Engine.createLoadFileUsePresetPayload("", preset)))
  }

  public func sendMIDI(bytes: [UInt8], when: AUEventSampleTime = 0, cable: UInt8 = 0) -> Bool {
    log.info("sendMIDI BEGIN - \(bytes.count) bytes")
    guard let block = unsafe auAudioUnit.scheduleMIDIEventBlock else {
      log.error("sendMIDI - nil scheduleMIDIEventBlock")
      return false
    }
    unsafe block(when, cable, bytes.count, bytes)
    return true
  }
}
