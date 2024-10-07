import AVFoundation
import Dependencies
import SwiftData

extension SchemaV1 {

  @Model
  public final class AudioSettingsModel {
    public var keyboardLowestNote: Int?
    public var keyboardLowestNoteEnabled: Bool
    public var pitchBendRange: Int?
    public var gain: Float
    public var pan: Float
    public var presetTuning: Float
    public var presetTranspose: Int?

    public typealias GeneratorOverrides = [Int:AUValue]
    public typealias ZoneOverrides = [Int:GeneratorOverrides]

    /// Mapping of instrument zone indices and a mapping of generator overrides
    public var overrides: ZoneOverrides?

    @Relationship(deleteRule: .cascade)
    public var delayConfig: DelayConfigModel?

    @Relationship(deleteRule: .cascade)
    public var reverbConfig: ReverbConfigModel?

    public init() {
      keyboardLowestNoteEnabled = false
      gain = 1.0
      pan = 0.0
      presetTuning = 0.0
    }

    /**
     Add a generator override to the given zone.

     - parameter zone: the zone to modify
     - parameter index: the generator index to set
     - parameter value: the value to use for the generator
     */
    public func addOverride(zone: Int, generator index: Int, value: AUValue) {
      if self.overrides == nil {
        self.overrides = .init()
      }
      self.overrides?[zone, default: .init()][index] = value
    }

    public func override(zone: Int, generator: Int) -> AUValue? {
      self.overrides?[zone]?[generator]
    }
    /**
     Remove a generator override from the given zone if one was set. if no more overrides exist, the
     (empty) collection for the zone will be removed as well.

     - parameter zone: the zone to modify
     - parameter index: the generator index to remove
     */
    public func removeOverride(zone: Int, generator: Int) {
      guard var zoneOverrides = self.overrides?[zone] else { return }
      zoneOverrides.removeValue(forKey: generator)
      if zoneOverrides.isEmpty {
        self.overrides?.removeValue(forKey: zone)
      } else {
        self.overrides?[zone] = zoneOverrides
      }
    }

    /**
     Remove all overrides for the given zone.

     - parameter zone: the zone to modify
     */
    public func removeAllOverrides(zone: Int) {
      self.overrides?.removeValue(forKey: zone)
    }

    /**
     Remove all zone overrides.
     */
    public func removeAllOverrides() {
      self.overrides = nil
    }

    public func duplicate() throws -> AudioSettingsModel {
      @Dependency(\.modelContextProvider) var context
      let copy = AudioSettingsModel()
      context.insert(copy)

      copy.keyboardLowestNote = self.keyboardLowestNote
      copy.keyboardLowestNoteEnabled = self.keyboardLowestNoteEnabled
      copy.pitchBendRange = self.pitchBendRange
      copy.gain = self.gain
      copy.pan = self.pan
      copy.presetTuning = self.presetTuning
      copy.presetTranspose = self.presetTranspose
      copy.overrides = self.overrides
      copy.delayConfig = self.delayConfig?.duplicate()
      copy.reverbConfig = self.reverbConfig?.duplicate()

      try context.save()

      return copy
    }
  }
}

extension Int {
  public static var globalZone: Int { 0 }
}
