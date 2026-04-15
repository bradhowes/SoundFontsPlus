// Copyright © 2025 Brad Howes. All rights reserved.

#if os(iOS)

import Combine
import SwiftUI
import UIKit

/**
 Protocol for an entity that publishes `true`/`false` when a virtual keyboard appears/disappears.

 The default implementation emits `Bool` values derived from `UIResponder.keyboardWillShowNotification` (`true`) and
 `UIResponder.keyboardDidHideNotification` (`false`).
 */
public protocol KeyboardVisibilityPublisher {
  var keyboardVisibilityPublisher: AnyPublisher<Bool, Never> { get }
}

extension KeyboardVisibilityPublisher {

  /// - returns: publisher of `Bool` values, where `true` indicates that the on-screen keyboard will appear, and `false` indicates
  /// that it is going away.
  public var keyboardVisibilityPublisher: AnyPublisher<Bool, Never> {
    Publishers.Merge(
      NotificationCenter.default
        .publisher(for: UIResponder.keyboardWillShowNotification)
        .map { _ in true },
      NotificationCenter.default
        .publisher(for: UIResponder.keyboardWillHideNotification)
        .removeDuplicates()
        .map { _ in false }
    )
    .removeDuplicates()
    .eraseToAnyPublisher()
  }
}

#endif
