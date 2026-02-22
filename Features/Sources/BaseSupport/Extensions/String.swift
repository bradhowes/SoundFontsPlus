// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation

extension String {

  /**
   Returns a new string that is either this with leading/trailing whitespace characters removed, or if that is empty,
   the given value.

   - parameter default: the value to use if our trimmed value results in an empty string
   - returns: trimmed content or given value
   */
  public func trimmed(or default: String) -> String {
    let trimmed = self.trimmedOfWhitespaces
    return trimmed.isEmpty ? `default` : trimmed
  }

  /// - returns content trimmed of whitespaces from start and end.
  @inlinable
  public var trimmedOfWhitespaces: String { trimmingCharacters(in: .whitespaces) }

  /// - returns: `Substring` that does not have the last extension.
  public var withoutExtension: Substring { self[self.startIndex..<(self.lastIndex(of: ".") ?? self.endIndex)] }
}

extension String {

  static let asciiAlphanumerics: CharacterSet = {
    var set = CharacterSet()
    set.insert(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
    return set
  }()

  func isAlphanumeric(ignoreDiacritics: Bool = false) -> Bool {
    !isEmpty && rangeOfCharacter(
      from: (ignoreDiacritics ? Self.asciiAlphanumerics : CharacterSet.alphanumerics).inverted
    ) == nil
  }
}

extension String {

  public enum TruncationPosition {
    case head
    case middle
    case tail
  }

  public func truncated(to limit: Int, with indicator: String = "…", at position: TruncationPosition = .tail) -> String {
    guard self.count > limit else { return self }
    switch position {
    case .head:
      return indicator + self.suffix(limit - indicator.count)
    case .middle:
      let headCharactersCount = Int(ceil(Float(limit - indicator.count) / 2.0))
      let tailCharactersCount = Int(floor(Float(limit - indicator.count) / 2.0))
      return "\(self.prefix(headCharactersCount))\(indicator)\(self.suffix(tailCharactersCount))"
    case .tail:
      return self.prefix(limit - indicator.count) + indicator
    }
  }
}
