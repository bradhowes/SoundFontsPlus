// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation

extension String {

  /**
   Returns a new string that is either this with leading/trailing whitespace characters removed, or if that is empty,
   the given value.

   - parameter default: the value to use if our trimmed value results in an empty string
   - returns trimmed content or given value
   */
  public func trimmed(or default: String) -> String {
    let trimmed = self.trimmedOfWhitespaces
    return trimmed.isEmpty ? `default` : trimmed
  }

  @inlinable
  public var trimmedOfWhitespaces: String { trimmingCharacters(in: .whitespaces) }

  public var withoutExtension: Substring { self[self.startIndex..<(self.lastIndex(of: ".") ?? self.endIndex)] }
}
