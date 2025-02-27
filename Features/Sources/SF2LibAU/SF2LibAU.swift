// Copyright © 2025 Brad Howes. All rights reserved.

import AudioToolbox
import CoreAudioKit
import os
import Engine

/**
 AUv3 component for SF2Lib engine.
 */
public final class SF2LibAU: AUAudioUnit {
  private let log: OSLog
  private var _audioUnitName: String?
  private var _audioUnitShortName: String?
  private var _currentPreset: AUAudioUnitPreset?
  private var engine: Engine.SF2.Engine

  private var dryBus: AUAudioUnitBus!
  private var reverbSendBus: AUAudioUnitBus!
  private var chorusSendBus: AUAudioUnitBus!

  // We have no inputs
  private lazy var _inputBusses: AUAudioUnitBusArray = AUAudioUnitBusArray(
    audioUnit: self, busType: .input, busses: [])

  // We have three outputs -- dry, reverb, chorus
  private lazy var _outputBusses: AUAudioUnitBusArray = AUAudioUnitBusArray(
    audioUnit: self, busType: .output, busses: [dryBus!, reverbSendBus!, chorusSendBus!])

  public override var inputBusses: AUAudioUnitBusArray { return _inputBusses }
  public override var outputBusses: AUAudioUnitBusArray { return _outputBusses }

  public enum Failure: Error {
    case invalidFormat
    case creatingBus(name: String)
  }

  /**
   Construct a new AUv3 component.

   - parameter componentDescription: the definition used when locating the component to create
   */
  public override init(componentDescription: AudioComponentDescription,
                       options: AudioComponentInstantiationOptions = []) throws {
    let loggingSubsystem = "com.braysoftware"
    let log = OSLog(subsystem: loggingSubsystem, category: "SF2LibAU")
    self.log = log

    os_log(.debug, log: log, "init - flags: %d man: %d type: sub: %d", componentDescription.componentFlags,
           componentDescription.componentManufacturer, componentDescription.componentType,
           componentDescription.componentSubType)

    // This may be too early to do this. I *think* the ideal flow is to postpone this kind of format determination
    // until `allocateRenderResources` is called, at which point we query the output bus for the format and use that
    // to initialize everything else. However, early testing indicated that the busses need to be present before this
    // call, so we do this dance of creating them with an "expected" format, and then we will adjust our beliefs within
    // the `allocateRenderResources` call.
    guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 2,
                                     interleaved: false) else {
      throw Failure.invalidFormat
    }

    self.engine = Engine.SF2.Engine(format.sampleRate, getVoiceCount())

    os_log(.debug, log: log, "super.init")
    do {
      try super.init(componentDescription: componentDescription, options: options)
    } catch {
      os_log(.error, log: log, "failed to initialize AUAudioUnit - %{public}s", error.localizedDescription)
      throw error
    }

    dryBus = try createBus(name: "dry", format: format)
    reverbSendBus = try createBus(name: "reverbSend", format: format)
    chorusSendBus = try createBus(name: "chorusSend", format: format)

    os_log(.debug, log: log, "init - done")
  }
}

extension SF2LibAU {

  func createLoadFileUseIndex(path: String, preset: Int) -> Data {
    return engine.createLoadFileUseIndex(std.string(path), preset)
  }

  func createUseIndex(index: Int) -> Data {
    return engine.createUseIndex(index)
  }

  func createResetCommand() -> Data {
    return engine.createResetCommand()
  }

  func createUseBankProgram(bank: UInt16, program: UInt8) -> [Data] {
    return engine.createUseBankProgram(bank, program)
  }

  func createChannelMessage(message: UInt8, value: UInt8) -> Data {
    return engine.createChannelMessage(message, value)
  }

  var activePresetName: String { String(engine.activePresetName()).trimmingCharacters(in: .whitespaces) }

  var activeVoiceCount: Int { return engine.activeVoiceCount() }

  var monophonicModeEnabled: Bool { return engine.monophonicModeEnabled(); }
  var polyphonicModeEnabled: Bool { return engine.polyphonicModeEnabled(); }
  var oneVoicePerKeyModeEnabled: Bool { return engine.oneVoicePerKeyModeEnabled(); }
  var retriggerModeEnabled: Bool { return engine.retriggerModeEnabled(); }
  var portamentoModeEnabled: Bool { return engine.portamentoModeEnabled() }
}

extension SF2LibAU {

  private func createBus(name: String, format: AVAudioFormat) throws -> AUAudioUnitBus {
    do {
      let bus = try AUAudioUnitBus(format: format)
      bus.name = name
      return bus
    } catch {
      os_log(.error, log: log, "failed to create %{public}s bus - %{public}s", error.localizedDescription)
      throw Failure.creatingBus(name: name)
    }
  }

  private func updateShortName() {
    let presetName = self.activePresetName
    self.audioUnitShortName = presetName.isEmpty ? "-NA-" : presetName
  }
}

extension SF2LibAU {

  public override var audioUnitName: String? {
    get { _audioUnitName }
    set {
      os_log(.debug, log: log, "audioUnitName set - %{public}s", newValue ?? "???")
      willChangeValue(forKey: "audioUnitName")
      _audioUnitName = newValue
      didChangeValue(forKey: "audioUnitName")
    }
  }

  public override var audioUnitShortName: String? {
    get { _audioUnitShortName }
    set {
      os_log(.debug, log: log, "audioUnitShortName set - %{public}s", newValue ?? "???")
      willChangeValue(forKey: "audioUnitShortName")
      _audioUnitShortName = newValue
      didChangeValue(forKey: "audioUnitShortName")
    }
  }

  public override func supportedViewConfigurations(_ viewConfigs: [AUAudioUnitViewConfiguration]) -> IndexSet {
    os_log(.debug, log: log, "supportedViewConfigurations")
    let indices = viewConfigs.enumerated().compactMap { $0.0 }
    os_log(.debug, log: log, "indices: %{public}s", indices.debugDescription)
    return IndexSet(indices)
  }

  public override func allocateRenderResources() throws {
    os_log(.debug, log: log, "allocateRenderResources BEGIN - outputBusses: %{public}d", outputBusses.count)

    // We assume that someone is using the `dryBus` and has it connected so we can query it to get the proper audio
    // processing format to use for the best performance and quality.
    let format = dryBus.format

    // Adjust the engine to use the given format. The engine is sensitive to the sample rate and channel count. The host
    // has set the `maximumFramesToRender` so we also forward that along.
    engine.setRenderingFormat(3, format, maximumFramesToRender)

    // NOTE: not sure this is correct behavior.
    for index in 0..<outputBusses.count {
      outputBusses[index].shouldAllocateBuffer = true
    }

    // Per doc, we must invoke the original method we are overriding.
    do {
      try super.allocateRenderResources()
    } catch {
      os_log(.error, log: log, "allocateRenderResources failed - %{public}s", error.localizedDescription)
      throw error
    }

    os_log(.debug, log: log, "allocateRenderResources END")
  }

  public override func deallocateRenderResources() {
    os_log(.debug, log: log, "deallocateRenderResources")
    super.deallocateRenderResources()
  }

  // We do not process input
  public override var canPerformInput: Bool { false }

  // We do generate output
  public override var canPerformOutput: Bool { true }

  /// Provide a block that asks the internal SF2 `engine` to render samples.
  public override var internalRenderBlock: AUInternalRenderBlock {
    let bus: NSInteger = 0;
    // Make private 'copy' of the engine for capturing by the block. This mirrors what we would do with Objective-C.
    var engine = self.engine
    return {flags, timestamp, frameCount, _, output, realtimeEventListHead, pullInputBlock in
      engine.processAndRender(timestamp, frameCount, bus, output, realtimeEventListHead,
                              pullInputBlock);
    }
  }
}

// MARK: - State Management

extension SF2LibAU {

  private var activeSoundFontPresetKey: String { "soundFontPatch" } // Legacy name -- do not change

  public override var fullState: [String: Any]? {
    get {
      os_log(.debug, log: log, "fullState GET")
      var state = [String: Any]()
      addInstanceSettings(into: &state)
      return state
    }
    set {
      os_log(.debug, log: log, "fullState SET")
      if let state = newValue {
        restoreInstanceSettings(from: state)
      }
    }
  }

  /**
   Save into a state dictionary the settings that are really part of an AUv3 instance

   - parameter state: the storage to hold the settings
   */
  private func addInstanceSettings(into state: inout [String: Any]) {
    os_log(.debug, log: log, "addInstanceSettings BEGIN")

    //    if let dict = self.activePresetManager.active.encodeToDict() {
    //      state[activeSoundFontPresetKey] = dict
    //    }
    //
    //    state[SettingKeys.activeTagKey.key] = settings.activeTagKey.uuidString
    //    state[SettingKeys.globalTuning.key] = settings.globalTuning
    //    state[SettingKeys.pitchBendRange.key] = settings.pitchBendRange
    //    state[SettingKeys.presetsWidthMultiplier.key] = settings.presetsWidthMultiplier
    //    state[SettingKeys.showingFavorites.key] = settings.showingFavorites

    os_log(.debug, log: log, "addInstanceSettings END")
  }

  /**
   Restore from a state dictionary the settings that are really part of an AUv3 instance

   - parameter state: the storage that holds the settings
   */
  private func restoreInstanceSettings(from state: [String: Any]) {
    os_log(.debug, log: log, "restoreInstanceSettings BEGIN")

    //    settings.setAudioUnitState(state)
    //
    //    let value: ActivePresetKind = {
    //      // First try current representation as a dict
    //      if let dict = state[activeSoundFontPresetKey] as? [String: Any],
    //         let value = ActivePresetKind.decodeFromDict(dict) {
    //        return value
    //      }
    //      // Fall back and try Data encoding
    //      if let data = state[activeSoundFontPresetKey] as? Data,
    //         let value = ActivePresetKind.decodeFromData(data) {
    //        return value
    //      }
    //      // Nothing known.
    //      return .none
    //    }()
    //
    //    self.activePresetManager.restoreActive(value)
    //
    //    if let activeTagKeyString = state[SettingKeys.activeTagKey.key] as? String,
    //       let activeTagKey = UUID(uuidString: activeTagKeyString) {
    //      settings.activeTagKey = activeTagKey
    //    }

    os_log(.debug, log: log, "restoreInstanceSettings END")
  }
}

// MARK: - User Presets Management

extension SF2LibAU {

  public override var supportsUserPresets: Bool { true }

  public override var currentPreset: AUAudioUnitPreset? {
    get { _currentPreset }
    set {
      guard let preset = newValue else {
        _currentPreset = nil
        return
      }

      _currentPreset = preset

      if preset.number < 0 {
        if let fullState = try? presetState(for: preset) {
          self.fullState = fullState
        }
      }
    }
  }
}

let defaultVoiceCount: UInt = 96

private func getVoiceCount() -> UInt {
  guard let infoDictionary: [String: Any] = Bundle(for: SF2LibAU.self).infoDictionary,
        let voiceCountSetting: String = infoDictionary["SF2LibAUVoiceCount"] as? String,
        let voiceCount: UInt = UInt(voiceCountSetting)
  else {
    return defaultVoiceCount
  }
  return voiceCount
}

