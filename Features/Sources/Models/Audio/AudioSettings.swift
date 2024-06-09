// Copyright © 2024 Brad Howes. All rights reserved.

import AVFoundation
import Foundation
import SwiftData

public typealias AudioSettings = SchemaV1.AudioSettings

extension SchemaV1 {

  @Model
  public final class AudioSettings {
    public var keyboardLowestNote: Int?
    public var keyboardLowestNoteEnabled: Bool = false
    public var pitchBendRange: Int?
    public var gain: Float = 0.0
    public var pan: Float = 0.0
    public var presetTuning: Float = 0.0
    public var presetTranspose: Int?

    public typealias GeneratorOverrides = [Int:AUValue]
    public typealias ZoneOverrides = [Int:GeneratorOverrides]

    /// Mapping of instrument zone indices and a mapping of generator overrides
    public var overrides: ZoneOverrides = [:]

    @Relationship(deleteRule: .cascade) public var reverbConfig: ReverbConfig?
    @Relationship(deleteRule: .cascade) public var delayConfig: DelayConfig?

    public init() {}

    /**
     Access the generator mapping associated with the given zone index for reading and writing.

     - parameter index: the zone index to find
     - returns: the mapping for the zone if it exists, otherwise nil.
     */
    subscript(_ index: Int) -> GeneratorOverrides? {
      get { self.overrides[index] }
      set { self.overrides[index] = newValue }
    }

    /**
     Add a generator override to the given zone.

     - parameter zone: the zone to modify
     - parameter index: the generator index to set
     - parameter value: the value to use for the generator
     */
    func addOverride(to zone: Int, generator index: Int, value: AUValue) {
      self.overrides[zone, default: .init()][index] = value
    }

    /**
     Remove a generator override from the given zone if one was set. if no more overrides exist, the
     (empty) collection for the zone will be removed as well.

     - parameter zone: the zone to modify
     - parameter index: the generator index to remove
     */
    func removeOverride(from zone: Int, generator: Int) {
      guard var zoneOverrides = self.overrides[zone] else { return }
      zoneOverrides.removeValue(forKey: generator)
      if zoneOverrides.isEmpty {
        self.overrides.removeValue(forKey: zone)
      } else {
        self.overrides[zone] = zoneOverrides
      }
    }

    /**
     Remove all overrides for the given zone.

     - parameter zone: the zone to modify
     */
    func removeAllOverrides(from zone: Int) {
      self.overrides.removeValue(forKey: zone)
    }

    /**
     Remove all zone overrides.
     */
    func removeAllOverrides() {
      self.overrides.removeAll()
    }
  }
}

public extension Int {
  static let globalZone: Int = -1
}

extension SchemaV1.AudioSettings : Identifiable {
  public var id: PersistentIdentifier { persistentModelID }
}
