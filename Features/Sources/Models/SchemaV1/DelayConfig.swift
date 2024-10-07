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

    public init(
      time: AUValue = 0.0,
      feedback: AUValue = 0.0,
      cutoff: AUValue = 0.0,
      wetDryMix: AUValue = 0.5,
      enabled: Bool = true
    ) {
      self.time = time
      self.feedback = feedback
      self.cutoff = cutoff
      self.wetDryMix = wetDryMix
      self.enabled = enabled
    }

    public func duplicate() -> DelayConfigModel {
      .init(
        time: self.time,
        feedback: self.feedback,
        cutoff: self.cutoff,
        wetDryMix: self.wetDryMix,
        enabled: self.enabled
      )
    }
  }
}
