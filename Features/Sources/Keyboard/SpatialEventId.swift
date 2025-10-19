// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import SwiftUI

/**
 The `SpatialEventGesture.Value.Element.ID` type is hidden from us. All we know is it is hashable.
 The following protocol replicates what is known of the ID type so that we can mock it in a test
 and inject in actions sent to a Keyboard store.
 */
public protocol SpatialEventId {
  func hash(into hasher: inout Hasher)
  static func ==(a: Self, b: Self) -> Bool
}

extension SpatialEventGesture.Value.Element.ID: SpatialEventId {}
