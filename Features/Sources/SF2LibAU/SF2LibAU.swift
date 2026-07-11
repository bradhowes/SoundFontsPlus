// Copyright © 2025 Brad Howes. All rights reserved.

import AudioToolbox
import BaseSupport
import CoreAudioKit
import Dependencies
import Engine
import Models

private let unsetAudioUnitShortName = "-"

/**
 AUv3 component for SF2Lib engine. Wrapped in an `AVAudioUnitMIDIInstrument` when created via `AVAudioUnit/instantiate`.

 When created for use in the SoundFontsPlus app, it will have no UI. However, the `SoundFontsPlusAU` target does, created via the
 `AUv3Root` feature.

 For proper AUv3 operation, we have to be careful how we interact with the rendering thread which begins with the function closure
 returned from ``internalRenderBlock``. The code there immediately calls into SF2Lib's Engine code.

 The AUv3 component needs to react to changes to ``fullState`` which can be set by a host to reconfigure the AUv3 component. The
 code pulls out bits that allow the audio unit to set the right sound font and preset to use. However, the user can change the
 current preset at any time, and if the host then queries the ``fullState`` value, it must contain the right bits so that a later
 restoration of the ``fullState`` value will restore the use of the updated sound font and preset.
 */
@objc public final class SF2LibAU: AUAudioUnit {

  private var _audioUnitShortName: String = unsetAudioUnitShortName
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

  public var fullStateChanged: () -> Void = {}

  public override var inputBusses: AUAudioUnitBusArray { return _inputBusses }
  public override var outputBusses: AUAudioUnitBusArray { return _outputBusses }

  public enum Failure: Error {
    case invalidFormat
    case creatingBus(name: String)
  }

  /**
   Construct a new AUv3 component.

   - parameter componentDescription: the definition used when locating the component to create
   - parameter options: instantiation options to apply
   */
  public override init(
    componentDescription: AudioComponentDescription,
    options: AudioComponentInstantiationOptions = []
  ) throws {
    log.info(
"""
init - flags: \(componentDescription.componentFlags, privacy: .public) \
man: \(componentDescription.componentManufacturer.stringValue, privacy: .public) \
type: \(componentDescription.componentType.stringValue, privacy: .public) \
sub: \(componentDescription.componentSubType.stringValue, privacy: .public)
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
\(acd.componentSubType.stringValue, privacy: .public), \
\(acd.componentManufacturer.stringValue, privacy: .public)
"""
    )
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

  @objc public dynamic override var audioUnitShortName: String? { _audioUnitShortName }

  public override func supportedViewConfigurations(_ viewConfigs: [AUAudioUnitViewConfiguration]) -> IndexSet {
    log.info("supportedViewConfigurations")
    let indices = viewConfigs.indices
    log.info("indices: \(indices, privacy: .public)")
    return IndexSet(indices)
  }

  public override func allocateRenderResources() throws {
    log.info("allocateRenderResources BEGIN - outputBusses: \(self.outputBusses.count, privacy: .public)")

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
    get { generateFullState() }
    set { applyFullState(newValue) }
  }

  private func generateFullState() -> [String: Any]? {
    log.info("generateFullState BEGIN")

    var state = super.fullState
    if let auv3ActiveState {
      do {
        state = try FullState(activeState: auv3ActiveState, base: state).state
      } catch {
        log.error("failed to generate full state value - \(error.localizedDescription, privacy: .public)")
      }
    }

    if let state {
      for (key, value) in state {
        log.debug(":: \(key, privacy: .public): \(String(describing: value), privacy: .public)")
      }
    }

    log.info("generateFullState END")
    return state
  }

  private func applyFullState(_ newValue: [String: Any]?) {
    log.info("applyFullState BEGIN")

    // Unlike in the getter, the base class throws an exception when given a value here.
    guard let state = newValue else {
      self.auv3ActiveState = nil
      log.info("applyFullState END - nil newValue")
      return
    }

    // Note: my understanding is `fullState` should not change while the render thread is active. So, using auv3ActiveState to
    // change the active preset will be OK when done via a change from an AUv3 host.
    //
    // However, the SoundFontsPlus app should *not* use this means to change the current preset since, in the app, the render
    // thread is always running.
    let newActiveState = FullState(state: state).activeState

    guard newActiveState != self.auv3ActiveState else {
      log.info("applyFullState END - unchanged auv3ActiveState")
      return
    }

    self.auv3ActiveState = newActiveState
    guard let newActiveState else {
      log.info("applyFullState END - nil/invalid activeState fron newValue")
      return
    }

    log.info("applyFullState - activeState: \(newActiveState, privacy: .public)")
    guard
      let presetLoadingInfo = newActiveState.presetLoadingInfo,
      let location = try? SoundFontKind(
        kind: presetLoadingInfo.kind,
        location: presetLoadingInfo.location,
        displayName: presetLoadingInfo.soundFontName
      )
    else {
      log.info("applyFullState END - failed to obtain valid location")
      return
    }

    if case let .external(bookmark) = location {
      if let data = bookmark.bookmark {
        log.info("applyFullState - calling engine.loadBookmarkAndPreset")
        let sent = sendLoadBookmark(data: data, presetIndex: presetLoadingInfo.presetIndex)
        log.info("applyFullState - sent: \(sent, privacy: .public)")
      }
    } else {
      log.info("applyFullState - calling engine.loadFileAndPreset")
      let sent = sendLoadURL(url: location.url, presetIndex: presetLoadingInfo.presetIndex)
      log.info("applyFullState - sent: \(sent, privacy: .public)")
    }

    // For the associated AUAudioUnitPreset we use the name of the preset and the negative preset index value (non-negative integer
    // values are for factory presets). These are just unique placeholders, not actually used for addressing presets.
    let preset = AUAudioUnitPreset()
    preset.number = -Int(newActiveState.presetIndex)
    preset.name = presetLoadingInfo.presetName
    currentPreset = preset

    willChangeValue(for: \.audioUnitShortName)
    log.info("applyFullState END - audioUnitShortName: \(presetLoadingInfo.presetName, privacy: .public)")
    _audioUnitShortName = presetLoadingInfo.presetName
    didChangeValue(for: \.audioUnitShortName)

    self.fullStateChanged()
  }

  private func sendLoadBookmark(data: Data, presetIndex: Int) -> Bool {
    sendMIDI(
      bytes: Array(
        SF2Engine.createLoadBookmarkUsePresetPayload(
          data,
          presetIndex
        )
      )
    )
  }

  private func sendLoadURL(url: URL, presetIndex: Int) -> Bool {
    sendMIDI(
      bytes: Array(
        SF2Engine.createLoadFileUsePresetPayload(
          std.string(url.path(percentEncoded: false)),
          presetIndex
        )
      )
    )
  }
}

// MARK: - User Presets Management

extension SF2LibAU {

  public override var supportsUserPresets: Bool { true }
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

private let log: Logger = .init(category: "SF2LibAU", loggingSubsystemValue: .loggingSubsystemAUv3Value)
