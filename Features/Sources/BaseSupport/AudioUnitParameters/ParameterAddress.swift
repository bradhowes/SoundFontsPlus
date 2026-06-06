// Copyright © 2025 Brad Howes. All rights reserved.

import AudioUnit.AUParameters

/**
 Enumeration of the AUParameterAddress values for parameters in the AUParameterTree of the main app. The parameter space
 is divided into two parts, one for the AUv3 plug-in (addresses \< 2000) and the main app (addreses >= 2000). This is
 only of concern for the app and not for the AUv3 plug-in.
 */
public enum ParameterAddress: AUParameterAddress, Sendable {

  case delayEnabled = 2000 // make sure no overlap with SF2Lib AUv3 plug-in which uses / reserves 0-1999
  case delayTime
  case delayFeedback
  case delayCutoff
  case delayAmount

  case reverbEnabled = 3000
  case reverbRoomIndex
  case reverbAmount

  static var count: Int { Self.allCases.count }
}

extension ParameterAddress {

  public var parameterDefinition: ParameterDefinition {
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

  public var parameter: AUParameter { parameterDefinition.parameter }

  public static func createParameterTree() -> AUParameterTree {
    AUParameterTree.createTree(withChildren: ParameterAddress.allCases.map(\.parameter))
  }
}

extension ParameterAddress: CaseIterable {}
