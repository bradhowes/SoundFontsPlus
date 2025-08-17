// Copyright © 2025 Brad Howes. All rights reserved.

import AUv3Shared
import AudioToolbox
import ComposableArchitecture
import CoreAudioKit
import os
import SF2LibAU
import Sharing
import SwiftUI

private let log = Logger(category: "Synth")

@Reducer
public struct SynthFeature {
  let audioFormat: AVAudioFormat! = AVAudioFormat(
    commonFormat: .pcmFormatFloat32,
    sampleRate: 48_000.0,
    channels: 2,
    interleaved: false
  )

  @ObservableState
  public struct State: Equatable {

    public static func == (lhs: SynthFeature.State, rhs: SynthFeature.State) -> Bool {
      lhs.loadedSoundFontId == rhs.loadedSoundFontId && lhs.loadedPresetIndex == rhs.loadedPresetIndex
    }

    let engine = AVAudioEngine()
    var loadedSoundFontId: SoundFont.ID?
    var loadedPresetIndex: Int?
  }

  public enum Action {
    case activePresetIdChanged
    case audioUnitCreated
    case becameActive
    case becameInactive
    case initialize
    case mediaServicesWereReset
    case routeChanged
    public enum Delegate {
      case createdSynth
    }
  }

  public var body: some ReducerOf<Self> {

    Reduce { state, action in
      switch action {
      case .activePresetIdChanged:
        return activePresetIdChanged(&state)

      case .audioUnitCreated:
        return installAudioUnit(&state)

      case .becameActive:
        return startAudioSession(&state)

      case .becameInactive:
        return stopAudioSession(&state)

      case .initialize:
        return initialize(&state)

      case .mediaServicesWereReset:
        return restartAudioSession(&state)

      case .routeChanged:
        return routeChanged(&state)
      }
    }
  }

  @Dependency(\.defaultDatabase) var database
  @Shared(.activeState) var activeState

  private enum CancelId {
    case createSynth
    case monitorActivePresetId
    case monitorMediaServices
    case monitorRouteChanged
    case playSample
  }
}

extension SF2LibAU: @retroactive @unchecked Sendable {}

extension SynthFeature {

  func activePresetIdChanged(_ state: inout State) -> Effect<Action> {
    log.info("activePresetIdChanged")

    @Shared(.synthAudioUnit) var synthAudioUnit
    guard let synth = synthAudioUnit?.synth else {
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
      result = synth.sendUsePreset(preset: presetInfo.presetIndex)
    } else {
      guard let location = try? SoundFontKind(kind: presetInfo.kind, location: presetInfo.location)
      else {
        log.error("unexpected nil location for \(presetInfo)")
        return .none
      }
      let path = location.path.path(percentEncoded: false)
      log.info("loading \(path) -- preset \(presetInfo.presetIndex) \(presetInfo.presetName)")
      result = synth.sendLoadFileUsePreset(path: path, preset: presetInfo.presetIndex)
    }

    log.info("loaded \(result)")
    guard result else { return .none }

    let firstTime = state.loadedSoundFontId == nil
    state.loadedSoundFontId = presetInfo.soundFontId
    state.loadedPresetIndex = presetInfo.presetIndex
    return firstTime ? .none : playNote(state, synth: synth)
  }

  func createSynth(_ state: inout State) -> Effect<Action> {
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
      let au = try await AVAudioUnit.instantiate(with: acd, options: [])
      @Shared(.synthAudioUnit) var synthAudioUnit
      $synthAudioUnit.withLock { $0 = au }

      log.info("createSynth - created")
      await send(.audioUnitCreated)
    }.cancellable(id: CancelId.createSynth, cancelInFlight: true)
  }

  func initialize(_ state: inout State) -> Effect<Action> {
    log.info("initialize")
    return .concatenate(
      createSynth(&state),
      .merge(
        monitorActivePresetId(&state),
        monitorMediaServices(&state),
        monitorRouteChanged(&state)
      )
    )
  }

  func installAudioUnit(_ state: inout State) -> Effect<Action> {
    log.info("installAudioUnit")
    @Shared(.synthAudioUnit) var synthAudioUnit
    @Shared(.delayEffect) var delayEffect
    @Shared(.reverbEffect) var reverbEffect

    guard let synthAudioUnit, let delayEffect, let reverbEffect else { return .none }

    log.info("attaching to engine")
    state.engine.attach(synthAudioUnit)
    state.engine.attach(delayEffect)
    state.engine.attach(reverbEffect)

    state.engine.connect(reverbEffect, to: state.engine.outputNode, format: audioFormat)
    state.engine.connect(delayEffect, to: reverbEffect, format: audioFormat)
    state.engine.connect(synthAudioUnit, to: delayEffect, format: audioFormat)

    log.info("starting")
    _ = startAudioSession(&state)

    return .send(.activePresetIdChanged)
  }

  func monitorActivePresetId(_ state: inout State) -> Effect<Action> {
    .publisher {
      $activeState.activePresetId
        .publisher
        .map { _ in .activePresetIdChanged }
    }.cancellable(id: CancelId.monitorActivePresetId, cancelInFlight: true)
  }

  func monitorMediaServices(_ state: inout State) -> Effect<Action> {
    .publisher {
      NotificationCenter.default
        .publisher(for: AVAudioSession.mediaServicesWereResetNotification)
        .map { _ in .mediaServicesWereReset }
    }.cancellable(id: CancelId.monitorMediaServices, cancelInFlight: true)
  }

  func monitorRouteChanged(_ state: inout State) -> Effect<Action> {
    .publisher {
      NotificationCenter.default
        .publisher(for: AVAudioSession.routeChangeNotification)
        .map { _ in .routeChanged }
    }.cancellable(id: CancelId.monitorRouteChanged, cancelInFlight: true)
  }

  func playNote(_ state: State, synth: SF2LibAU) -> Effect<Action> {
    @Shared(.playSoundOnPresetChange) var playSoundOnPresetChange
    guard playSoundOnPresetChange else { return .none }
    log.info("playNote")
    return .run { _ in
      // Play a short note using the new preset
      log.info("playNote - sendNoteOn")
      synth.sendNoteOn(note: 60)
      try? await Task.sleep(for: .milliseconds(250))
      log.info("playNote - sendNoteOff")
      synth.sendNoteOff(note: 60)
    }.cancellable(id: CancelId.playSample, cancelInFlight: true)
  }

  func restartAudioSession(_ state: inout State) -> Effect<Action> {
    log.error("recreateSynth - BEGIN")
    _ = stopAudioSession(&state)
    _ = startAudioSession(&state)
    log.error("recreateSynth - END")
    return .none
  }

  func routeChanged(_ state: inout State) -> Effect<Action> {
    let bufferSize: Int = 64
    let session = AVAudioSession.sharedInstance()

    do {
      log.info("routeChanged - setting AudioSession category")
      try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
    } catch let error as NSError {
      let err = error.localizedDescription
      log.error("routeChanged - failed to set the audio session category and mode: \(err)")
    }

    log.info("routeChanged - sampleRate: \(AVAudioSession.sharedInstance().sampleRate)")
    log.info("routeChanged - preferredSampleRate: \(AVAudioSession.sharedInstance().sampleRate)")

    do {
      log.info("routeChanged - setting preferred sample rate")
      try session.setPreferredSampleRate(audioFormat.sampleRate)
    } catch let error as NSError {
      let err = error.localizedDescription
      log.error("routeChanged - failed to set the preferred sample rate to \(audioFormat.sampleRate) - \(err)")
    }

    let bufferDuration = Double(bufferSize) / audioFormat.sampleRate
    do {
      log.info("routeChanged - setting IO buffer duration \(bufferDuration)")
      try session.setPreferredIOBufferDuration(bufferDuration)
    } catch let error as NSError {
      let err = error.localizedDescription
      log.error("routeChanged - failed to set the preferred buffer size to \(bufferSize) - \(err)")
    }

    do {
      log.info("routeChanged - setting active audio session")
      try session.setActive(true, options: [])
    } catch {
      let err = error.localizedDescription
      log.error("routeChanged - failed to set active - \(err)")
    }

    dump(route: session.currentRoute)

    return .none
  }

  func startAudioSession(_ state: inout State) -> Effect<Action> {
    log.info("startAudioSession BEGIN")

    _ = routeChanged(&state)

    do {
      log.info("startAudioSession - starting engine")
      try state.engine.start()
    } catch {
      log.error("startAudioSession - failed to start - \(error.localizedDescription)")
    }

    return .none
  }

  func stopAudioSession(_ state: inout State) -> Effect<Action> {
    log.info("stopAudioSession BEGIN")

    state.engine.stop()

    let session = AVAudioSession.sharedInstance()
    do {
      log.info("stopAudio - setting AudioSession to inactive")
      try session.setActive(false, options: [])
      log.info("stopAudio - done")
    } catch let error as NSError {
      log.error("stopAudio - Failed session.setActive(false): \(error.localizedDescription)")
    }

    log.info("stopAudio END")

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
