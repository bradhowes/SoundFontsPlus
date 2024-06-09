// Copyright © 2024 Brad Howes. All rights reserved.

import AVFoundation
import Foundation
import SwiftData

public typealias DelayConfig = SchemaV1.DelayConfig

extension SchemaV1 {

  @Model
  final public class DelayConfig {
    public var time: AUValue = 0.0
    public var feedback: AUValue = 0.0
    public var cutoff: AUValue = 0.0
    public var wetDryMix: AUValue = 0.5
    public var enabled = true

    public init() {}
  }
}

extension SchemaV1.DelayConfig : Identifiable {
  public var id: PersistentIdentifier { persistentModelID }
}
