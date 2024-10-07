import AVFoundation
import SwiftData

extension SchemaV1 {

  @Model
  final public class ReverbConfigModel {
    public var preset: Int
    public var wetDryMix: AUValue
    public var enabled: Bool

    public init(preset: Int = 0, wetDryMix: AUValue = 0.5, enabled: Bool = true) {
      self.preset = preset
      self.wetDryMix = wetDryMix
      self.enabled = enabled
    }

    public func duplicate() -> ReverbConfigModel {
      .init(preset: preset, wetDryMix: wetDryMix, enabled: enabled)
    }
  }
}
