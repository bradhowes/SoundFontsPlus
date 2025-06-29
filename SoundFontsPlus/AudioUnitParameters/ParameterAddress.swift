import AudioUnit.AUParameters

enum ParameterAddress: AUParameterAddress, CaseIterable {

  case delayEnabled = 2000
  case delayTime
  case delayFeedback
  case delayCutoff
  case delayAmount

  case reverbEnabled = 3000
  case reverbRoomIndex
  case reverbAmount
}

extension ParameterAddress {

  var parameterDefinition: ParameterDefinition {
    switch self {

    case .delayEnabled:
      return .bool(
        "delayEnabled",
        localized: "Enabled",
        address: self
      )
    case .delayTime:
      return .float(
        "delayTime",
        localized: "Time",
        address: self,
        range: 0.0...2,
        unit: .seconds,
        logScale: true
      )
    case .delayFeedback:
      return .float(
        "delayFeedback",
        localized: "Feedback",
        address: self,
        range: -100...100,
        unit: .percent
      )
    case .delayCutoff:
      return .float(
        "delayCutoff",
        localized: "Cutoff",
        address: self,
        range: 10...20_000,
        unit: .hertz,
        logScale: true
      )
    case .delayAmount:
      return .percent(
        "delayAmount",
        localized: "Amount",
        address: self
      )
    case .reverbEnabled: return
        .bool(
          "reverbEnabled",
          localized: "Enabled",
          address: self
        )
    case .reverbRoomIndex: return
        .float(
          "reverbRoom",
          localized: "Room",
          address: self,
          range: 0...13,
          unit: .generic
        )
    case .reverbAmount: return
        .percent(
          "reverbAmount",
          localized: "Amount",
          address: self
        )
    }
  }

  var parameter: AUParameter { parameterDefinition.parameter }

  static func createParameterTree() -> AUParameterTree {
    AUParameterTree.createTree(withChildren: ParameterAddress.allCases.map(\.parameter))
  }
}
