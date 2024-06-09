// Copyright © 2024 Brad Howes. All rights reserved.

import AVFoundation
import Foundation
import SwiftData

public typealias ReverbConfig = SchemaV1.ReverbConfig

extension SchemaV1 {

  @Model
  final public class ReverbConfig {
    public var preset: Int = 0
    public var wetDryMix: AUValue = 0.5
    public var enabled = true

    public init() {}
  }
}

extension SchemaV1.ReverbConfig : Identifiable {
  public var id: PersistentIdentifier { persistentModelID }
}
