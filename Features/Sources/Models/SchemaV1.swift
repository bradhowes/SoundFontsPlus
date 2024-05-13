// Copyright © 2024 Brad Howes. All rights reserved.

import SwiftData

public typealias CurrentSchema = SchemaV1

public enum SchemaV1: VersionedSchema {

  public static var versionIdentifier: Schema.Version { .init(1, 0, 0) }

  public static var models: [any PersistentModel.Type] {
    [
      AudioSettings.self,
      DelayConfig.self,
      Favorite.self,
      Preset.self,
      PresetInfo.self,
      ReverbConfig.self,
      SoundFont.self,
      Tag.self
    ]
  }
}
