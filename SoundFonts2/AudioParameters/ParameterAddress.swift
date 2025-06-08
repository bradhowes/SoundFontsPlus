import AudioUnit.AUParameters

enum ParameterAddress: AUParameterAddress, CaseIterable {

  case delayEnabled = 2000
  case delayTime
  case delayFeedback
  case delayCutoff
  case delayWetDryMix

  case reverbEnabled = 3000
  case reverbRoomIndex
  case reverbWetDryMix
}

extension ParameterAddress {

  var parameterDefinition: ParameterDefinition {
    switch self {

    case .delayEnabled:
      return .bool(
        "delayEnabled",
        localized: "DelayEnabled",
        address: self
      )
    case .delayTime:
      return .float(
        "delayTime",
        localized: "DelayTime",
        address: self,
        range: 0.0...2,
        unit: .seconds,
        logScale: true
      )
    case .delayFeedback:
      return .float(
        "delayFeedback",
        localized: "DelayFeedback",
        address: self,
        range: -100...100,
        unit: .percent
      )
    case .delayCutoff:
      return .float(
        "delayCutoff",
        localized: "DelayCutoff",
        address: self,
        range: 10...20_000,
        unit: .hertz,
        logScale: true
      )
    case .delayWetDryMix:
      return .percent(
        "delayMix",
        localized: "DelayMix",
        address: self
      )

    case .reverbEnabled: return
        .bool(
          "reverbEnabled",
          localized: "ReverbEnabled",
          address: self
        )
    case .reverbRoomIndex: return
        .float(
          "reverbRoom",
          localized: "ReverbRoom",
          address: self,
          range: 0...13,
          unit: .generic
        )
    case .reverbWetDryMix: return
        .percent(
          "reverbMix",
          localized: "ReverbMix",
          address: self
        )
    }
  }

  var parameter: AUParameter { parameterDefinition.parameter }

  static func createParameterTree() -> AUParameterTree {
    AUParameterTree.createTree(withChildren: ParameterAddress.allCases.map(\.parameter))
  }
}
