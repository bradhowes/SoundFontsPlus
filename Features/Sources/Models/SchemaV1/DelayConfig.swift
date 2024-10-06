import AVFoundation
import SwiftData

extension SchemaV1 {

  @Model
  final public class DelayConfigModel {
    public var time: AUValue
    public var feedback: AUValue
    public var cutoff: AUValue
    public var wetDryMix: AUValue
    public var enabled: Bool

    public init() {
      time = 0.0
      feedback = 0.0
      cutoff = 0.0
      wetDryMix = 0.5
      enabled = true
    }
  }
}
