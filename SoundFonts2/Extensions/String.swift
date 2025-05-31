// Copyright © 2025 Brad Howes. All rights reserved.

extension String {

  /**
   Returns a new string that is either this with leading/trailing whitespace characters removed, or if that is empty,
   the given value.

   - parameter default: the value to use if our trimmed value results in an empty string
   - returns trimmed content or given value
   */
  public func trimmed(or default: String) -> String {
    let trimmed = self.trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty ? `default` : trimmed
  }
}
