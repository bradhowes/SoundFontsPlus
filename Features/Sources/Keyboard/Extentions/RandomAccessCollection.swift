// Copyright © 2025 Brad Howes. All rights reserved.

import BaseSupport
import Foundation
import SwiftUI

extension RandomAccessCollection where Element == CGRect, Index == Int {

  /**
   Obtain the index of the key in the collection that corresponds to the given position. Performs a binary search to
   quickly locate the best candidate. NOTE: pretty sure this can be done in constant time via straightforward math.

   - parameter point: the location to consider
   - returns: index where to insert
   */
  func orderedInsertionIndex(for point: CGPoint) -> Index {
    var low = startIndex
    var high = endIndex

    while low != high {
      let mid = index(low, offsetBy: distance(from: low, to: high) / 2)
      let frame = self[mid]
      if frame.contains(point) {
        low = mid
        break
      }
      if frame.midX < point.x {
        low = index(after: mid)
      } else {
        high = mid
      }
    }

    // Don't continue if outside of collection
    guard low < endIndex else { return endIndex }

    // Don't continue if referencing an accented note -- there is no ambiguity and we have what we want
    let key = Note(midiNoteValue: distance(from: startIndex, to: low))
    guard !key.accented else { return low }

    // Point is in the region of a white key. Check if previous or next key is accented and has the point to handle the
    // overlap of the black keys on the white ones.
    let next = index(after: low)
    if next != endIndex && Note(midiNoteValue: next).accented && self[next].contains(point) {
      return next
    }

    let prev = index(before: low)
    if prev >= startIndex && Note(midiNoteValue: prev).accented && self[prev].contains(point) {
      return prev
    }

    return low
  }
}
