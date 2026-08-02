// Copyright © 2025 Brad Howes. All rights reserved.

public import SF2Resources
public import Tagged

extension SF2ResourceTag {
  public var soundFontId: SoundFont.ID { .init(rawValue: Int64(self.rawValue)) }
}
