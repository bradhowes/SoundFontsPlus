// Copyright © 2025 Brad Howes. All rights reserved.

import Combine
import UIKit
import SwiftUI

public protocol KeyboardVisibilityPublisher {

  var keyboardVisibilityPublisher: AnyPublisher<Bool, Never> { get }
}

extension KeyboardVisibilityPublisher {

  public var keyboardVisibilityPublisher: AnyPublisher<Bool, Never> {
    Publishers.Merge(
      NotificationCenter.default
        .publisher(for: UIResponder.keyboardWillShowNotification)
        .map { _ in true },
      NotificationCenter.default
        .publisher(for: UIResponder.keyboardDidHideNotification)
        .removeDuplicates()
        .map { _ in false }
    )
    .removeDuplicates()
    .eraseToAnyPublisher()
  }
}
