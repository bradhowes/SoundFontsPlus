// Copyright © 2025 Brad Howes. All rights reserved.

import Combine
import UIKit
import SwiftUI

protocol KeyboardReadable {
  var keyboardPublisher: AnyPublisher<Bool, Never> { get }
}

extension KeyboardReadable {
  var keyboardPublisher: AnyPublisher<Bool, Never> {
    Publishers.Merge(
      NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
        .map { _ in true },
      NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
        .map { _ in false }
    )
    .eraseToAnyPublisher()
  }
}
