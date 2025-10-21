// Copyright © 2025 Brad Howes. All rights reserved.

import SF2Resources

extension SF2ResourceTag {
  public var soundFontId: SoundFont.ID { .init(rawValue: Int64(self.rawValue)) }
}
