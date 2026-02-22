// Copyright © 2025 Brad Howes. All rights reserved.

import AudioToolbox
import BaseSupport
import CoreAudioKit
import Dependencies
import Engine
import Models

/**
 AUv3 component for SF2Lib engine. Wrapped in an ``AVAudioUnitMIDIInstrument`` when created via ``AVAudioUnit/instantiate``.

 When created for use in the SoundFontsPlus app, it will have no UI. However, the ``SoundFontsPlusAU`` target does, creatd via the
 ``AUv3Root`` feature.
 */
@objc public final class SF2LibAU: AUAudioUnit {

  private var _currentPreset: AUAudioUnitPreset?

  public private(set) var engine: SF2Engine = SF2Engine()
  public private(set) var auv3ActiveState: AUv3ActiveState?

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
  public override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
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
    guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 2, interleaved: false) else {
      throw Failure.invalidFormat
    }

    engine.create(format.sampleRate, getVoiceCount())
    dryBus = try Self.createBus(name: "dry", format: format)
    reverbSendBus = try Self.createBus(name: "reverbSend", format: format)
    chorusSendBus = try Self.createBus(name: "chorusSend", format: format)

    try super.init(componentDescription: componentDescription, options: options)

    log.info("init - creating parameterTree")
    self.parameterTree = engine.getParameterTree()

    log.info("init - done")
  }
}

extension SF2LibAU: @unchecked Sendable {}

extension SF2LibAU {

  /**
   Create a new SF2LibAU instance for use in the application.

   - parameter register: if `true` then register the component description to invoke the SF2LibAU class.
   - returns: created AVAudioUnitMIDIInstrument instance if successful
   */
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

  @objc public dynamic override var audioUnitName: String? {
    @Dependency(\.defaultDatabase) var defaultDatabase
    guard
      let activeState = auv3ActiveState,
      let presetInfo = PresetLoadingInfo.for(id: activeState.presetId)
    else {
      return "-"
    }
    return "\(presetInfo.soundFontName): \(presetInfo.presetName)"
  }

  @objc public dynamic override var audioUnitShortName: String? {
    let limit = 16
    let divider = ": "
    @Dependency(\.defaultDatabase) var defaultDatabase
    guard
      let activeState = auv3ActiveState,
      let presetInfo = PresetLoadingInfo.for(id: activeState.presetId)
    else {
      return "-"
    }

    let soundFontCount = presetInfo.soundFontName.count
    let presetCount = presetInfo.presetName.count

    if soundFontCount + presetCount + 2 <= limit {
      return "\(presetInfo.soundFontName)\(divider)\(presetInfo.presetName)"
    }

    let partLimit = (limit - divider.count) / 2
    return "\(presetInfo.soundFontName.truncated(to: partLimit))\(divider)\(presetInfo.presetName.truncated(to: partLimit))"
  }

  public override func supportedViewConfigurations(_ viewConfigs: [AUAudioUnitViewConfiguration]) -> IndexSet {
    log.info("supportedViewConfigurations")
    let indices = viewConfigs.indices
    log.info("indices: \(indices)")
    return IndexSet(indices)
  }

  public override func allocateRenderResources() throws {
    log.info("allocateRenderResources BEGIN - outputBusses: \(self.outputBusses.count)")

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

  @objc public dynamic override var fullState: [String: Any]? {
    get {
      log.info("fullState GET")
      var state = super.fullState
      if let auv3ActiveState {
        do {
          state = try FullState(activeState: auv3ActiveState, base: state).state
        } catch {
          log.error("failed to generate full state value - \(error.localizedDescription)")
        }
      }

      if let state {
        for (key, value) in state {
          log.debug(":: \(key): \(String(describing: value))")
        }
      }
      return state
    }
    set {
      log.info("fullState SET")
      willChangeValue(for: \.fullState)

      // Unlike in the getter, the base class throws an exception when given a value here.
      // super.fullState = newValue
      if let state = newValue {

        // Note: my understanding is `fullState` should not change while the render thread is active. So, using auv3ActiveState to
        // change the active preset will be OK when done via a change from an AUv3 host.
        //
        // However, the SoundFontsPlus app should *not* use this means to change the current preset since, in the app, the render
        // thread is always running.
        self.auv3ActiveState = FullState(state: state).activeState
        if let auv3ActiveState = self.auv3ActiveState {
          log.info("fullState - activeState: \(auv3ActiveState)")
          log.info("fullState - displayName: \(self.audioUnitShortName ?? "")")

          if auv3ActiveState.source == .auv3 {
            @Dependency(\.defaultDatabase) var defaultDatabase
            if let presetInfo = PresetLoadingInfo.for(id: auv3ActiveState.presetId) {
              // This active state value originally came from us (not from SoundFontsPlus app) so we can go ahead and command the
              // engine to load the file and use the preset.
              if let location = try? SoundFontKind(
                kind: presetInfo.kind,
                location: presetInfo.location,
                displayName: presetInfo.soundFontName
              ) {
                if case let .external(bookmark) = location {
                  if let data = bookmark.bookmark {
                    engine.loadBookmarkAndPreset(data, presetInfo.presetIndex)
                  }
                } else {
                  engine.loadFileAndPreset(
                    std.string(location.url.path(percentEncoded: false)),
                    presetInfo.presetIndex
                  )
                }

                let preset = AUAudioUnitPreset()
                preset.number = -Int(auv3ActiveState.presetId.rawValue)
                preset.name = presetInfo.presetName
                currentPreset = preset
              }
            }
          }
        }
      }
      didChangeValue(for: \.fullState)
    }
  }
}

// MARK: - User Presets Management

extension SF2LibAU {

  public override var supportsUserPresets: Bool { true }

  @objc public dynamic override var currentPreset: AUAudioUnitPreset? {
    get { _currentPreset }
    set {
      willChangeValue(forKey: "currentPreset")
      _currentPreset = newValue
      didChangeValue(forKey: "currentPreset")
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

private let log: Logger = .init(category: "SF2LibAU")
