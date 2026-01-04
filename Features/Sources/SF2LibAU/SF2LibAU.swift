// Copyright © 2025 Brad Howes. All rights reserved.

import AudioToolbox
import BaseSupport
import CoreAudioKit
import Dependencies
import Engine

/**
 AUv3 component for SF2Lib engine.
 */
public final class SF2LibAU: AUAudioUnit {

  private var _audioUnitName: String?
  private var _audioUnitShortName: String?
  private var _currentPreset: AUAudioUnitPreset?

  private var engine: SF2Engine = SF2Engine()
  private var dryBus: AUAudioUnitBus
  private var reverbSendBus: AUAudioUnitBus
  private var chorusSendBus: AUAudioUnitBus

  // We have no inputs
  private lazy var _inputBusses: AUAudioUnitBusArray = AUAudioUnitBusArray(
    audioUnit: self,
    busType: .input,
    busses: []
  )

  // We have three outputs -- dry, reverb, chorus
  private lazy var _outputBusses: AUAudioUnitBusArray = AUAudioUnitBusArray(
    audioUnit: self,
    busType: .output,
    busses: [dryBus, reverbSendBus, chorusSendBus]
  )

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
    log.info(
"""
init - flags: \(componentDescription.componentFlags) \
man: \(componentDescription.componentManufacturer) \
type: \(componentDescription.componentType) \
sub: \(componentDescription.componentSubType)
"""
    )

    // This may be too early to do this. I *think* the ideal flow is to postpone this kind of format determination
    // until `allocateRenderResources` is called, at which point we query the output bus for the format and use that
    // to initialize everything else. However, early testing indicated that the busses need to be present before this
    // call, so we do this dance of creating them with an "expected" format, and then we will adjust our beliefs within
    // the `allocateRenderResources` call.
    guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 2,
                                     interleaved: false) else {
      throw Failure.invalidFormat
    }

    engine.create(format.sampleRate, getVoiceCount())
    dryBus = try Self.createBus(name: "dry", format: format)
    reverbSendBus = try Self.createBus(name: "reverbSend", format: format)
    chorusSendBus = try Self.createBus(name: "chorusSend", format: format)

    try super.init(componentDescription: componentDescription, options: options)

    self.parameterTree = engine.getParameterTree()

    log.info("init - done")
  }
}

extension SF2LibAU: @unchecked Sendable {}

extension SF2LibAU {

  public static func create(register: Bool = false) async -> AVAudioUnitMIDIInstrument? {
    let acd = Bundle.main.audioComponentDescription
    if register {
      AUAudioUnit.registerSubclass(SF2LibAU.self, as: acd, name: "SoundFontsPlusAU", version: 1)
    }

    log.info(
      """
      create - instantiating audio unit for \
      \(acd.componentSubType.stringValue), \
      \(acd.componentManufacturer.stringValue)
      """)
#if os(iOS)
    let options: AudioComponentInstantiationOptions = []
#endif
#if os(macOS)
    let options: AudioComponentInstantiationOptions = [.loadInProcess]
#endif

    do {
      return try await AVAudioUnit.instantiate(with: acd, options: options) as? AVAudioUnitMIDIInstrument
    } catch {
      log.error("failed to instantiate audio unit: \(error)")
      return nil
    }
  }
}

extension SF2LibAU {

  public var activePresetName: String { String(engine.activePresetName()).trimmedOfWhitespaces }

  public var monophonicModeEnabled: Bool { engine.monophonicModeEnabled(); }
  public var polyphonicModeEnabled: Bool { engine.polyphonicModeEnabled(); }
  public var oneVoicePerKeyModeEnabled: Bool { engine.oneVoicePerKeyModeEnabled(); }
  public var retriggerModeEnabled: Bool { engine.retriggerModeEnabled(); }
  public var portamentoModeEnabled: Bool { engine.portamentoModeEnabled() }

  public func sendMIDI(bytes: [UInt8], when: AUEventSampleTime = 0, cable: UInt8 = 0) -> Bool {
    log.info("sendMIDI BEGIN - \(bytes.count) bytes")
    guard let block = unsafe scheduleMIDIEventBlock else {
      log.error("sendMIDI - nil scheduleMIDIEventBlock")
      return false
    }
    unsafe block(when, cable, bytes.count, bytes)
    return true
  }
}

extension SF2LibAU {

  private static func createBus(name: String, format: AVAudioFormat) throws -> AUAudioUnitBus {
    let bus = try AUAudioUnitBus(format: format)
    bus.name = name
    return bus
  }
}

extension SF2LibAU {

  public override var audioUnitName: String? {
    get { _audioUnitName }
    set {
      log.info("audioUnitName set - \(newValue.debugDescription)")
      willChangeValue(forKey: "audioUnitName")
      _audioUnitName = newValue
      didChangeValue(forKey: "audioUnitName")
    }
  }

  public override var audioUnitShortName: String? {
    get { _audioUnitShortName }
    set {
      log.info("audioUnitShortName set - \(newValue.debugDescription)")
      willChangeValue(forKey: "audioUnitShortName")
      _audioUnitShortName = newValue
      didChangeValue(forKey: "audioUnitShortName")
    }
  }

  public override func supportedViewConfigurations(_ viewConfigs: [AUAudioUnitViewConfiguration]) -> IndexSet {
    log.info("supportedViewConfigurations")
    let indices = viewConfigs.indices
    log.info("indices: \(indices)")
    return IndexSet(indices)
  }

  public override func allocateRenderResources() throws {
    log.info("allocateRenderResources BEGIN - outputBusses: \(outputBusses.count)")

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
    try super.allocateRenderResources()
    log.info("allocateRenderResources END")
  }

  public override func deallocateRenderResources() {
    log.info("deallocateRenderResources")
    super.deallocateRenderResources()
  }

  // We do not process input
  public override var canPerformInput: Bool { false }

  // We do generate output
  public override var canPerformOutput: Bool { true }

  /// Provide a block that asks the internal SF2 `engine` to render samples.
  public override var internalRenderBlock: AUInternalRenderBlock {
    log.info("internalRenderBlock BEGIN")
    return unsafe engine.getRenderBlock()
  }
}

// MARK: - State Management

extension SF2LibAU {

  private var activeSoundFontPresetKey: String { "soundFontPatch" } // Legacy name -- do not change

  public override var fullState: [String: Any]? {
    get {
      log.info("fullState GET")
      var state = [String: Any]()
      addInstanceSettings(into: &state)
      return state
    }
    set {
      log.info("fullState SET")
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
    log.info("addInstanceSettings BEGIN")

    //    if let dict = self.activePresetManager.active.encodeToDict() {
    //      state[activeSoundFontPresetKey] = dict
    //    }
    //
    //    state[SettingKeys.activeTagKey.key] = settings.activeTagKey.uuidString
    //    state[SettingKeys.globalTuning.key] = settings.globalTuning
    //    state[SettingKeys.pitchBendRange.key] = settings.pitchBendRange
    //    state[SettingKeys.presetsWidthMultiplier.key] = settings.presetsWidthMultiplier
    //    state[SettingKeys.showingFavorites.key] = settings.showingFavorites

    log.info("addInstanceSettings END")
  }

  /**
   Restore from a state dictionary the settings that are really part of an AUv3 instance

   - parameter state: the storage that holds the settings
   */
  private func restoreInstanceSettings(from state: [String: Any]) {
    log.info("restoreInstanceSettings BEGIN")

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

    log.info("restoreInstanceSettings END")
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

private let log = Logger(category: "SF2LibAU")
