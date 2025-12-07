import AudioToolbox.AudioComponent
import Dependencies

public struct SynthAUv3ComponentDescription: TestDependencyKey {

  // Obtain the component description for the SF2LibAU app extension. This relies on the `main` bundle for values.
  public static var liveValue: AudioComponentDescription {
    let bundle = Bundle.main
    let componentType = FourCharCode(stringLiteral: bundle.string(forKey: "AU_COMPONENT_TYPE"))
    // NOTE: do not use AU_COMPONENT_SUBTYPE until the AUv3 plugin is ready to use. Until then, need to point to
    // something that is unique.

    // let componentSubtype = FourCharCode(stringLiteral: "Sf2L")
    let componentSubtype = FourCharCode(stringLiteral: bundle.string(forKey: "AU_COMPONENT_SUBTYPE"))
    let componentManufacturer = FourCharCode(stringLiteral: bundle.string(forKey: "AU_COMPONENT_MANUFACTURER"))

    precondition(
      componentType != .invalidFourCharCode &&
      componentSubtype != .invalidFourCharCode &&
      componentManufacturer != .invalidFourCharCode
    )
    return .init(
      componentType: componentType,
      componentSubType: componentSubtype,
      componentManufacturer: componentManufacturer,
      componentFlags: 0,
      componentFlagsMask: 0
    )
  }

  // Obtain the component description for the SF2LibAU app extension to use for testing purposes when the `main` bundle
  // is not available.
  public static var testValue: AudioComponentDescription {
    .init(
      componentType: FourCharCode(stringLiteral: "aumu"),
      componentSubType: FourCharCode(stringLiteral: "Sf2L"),
      componentManufacturer: FourCharCode(stringLiteral: "BRay"),
      componentFlags: 0,
      componentFlagsMask: 0
    )
  }

  public static var previewValue: AudioComponentDescription { testValue }
}
