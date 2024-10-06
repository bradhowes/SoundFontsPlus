import AVFoundation
import SwiftData

extension SchemaV1 {

  @Model
  final public class ReverbConfigModel {
    public var preset: Int
    public var wetDryMix: AUValue
    public var enabled: Bool

    public init() {
      preset = 0
      wetDryMix = 0.5
      enabled = true
    }
  }
}
