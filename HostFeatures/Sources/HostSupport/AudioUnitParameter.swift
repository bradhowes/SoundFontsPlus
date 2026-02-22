import AudioToolbox.AudioUnitProperties
import Foundation

public struct AudioUnitParameter: CustomStringConvertible {
  public let id: Int
  public let name: String
  public let minValue: Float
  public let maxValue: Float
  public let defaultValue: Float
  public let unit: Int

  public init(_ info: AudioUnitParameterInfo, id: UInt32) {
    self.id = Int(id)
    if let cfName = info.cfNameString?.takeUnretainedValue() {
      name = String(cfName)
    } else {
      name = "?"
    }
    minValue = Float(info.minValue)
    maxValue = Float(info.maxValue)
    defaultValue = Float(info.defaultValue)
    unit = Int(info.unit.rawValue)
  }

  public var description: String {
    "Parameter [id: \(id)] :  \(name) [\(minValue)..\(maxValue)] \(unit)"
  }
}
