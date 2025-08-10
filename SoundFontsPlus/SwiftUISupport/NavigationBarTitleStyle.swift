// Copyright © 2025 Brad Howes. All rights reserved.

import SwiftUI

public func navigationBarTitleStyle() {
  if let big = UIFont(name: "Eurostile", size: 40) {
    UINavigationBar.appearance().largeTitleTextAttributes = [
      .font: big,
      .foregroundColor: UIColor.whiteText
    ]
  }

  if let normal = UIFont(name: "Eurostile", size: 20) {
    UINavigationBar.appearance().titleTextAttributes = [
      .font: normal,
      .foregroundColor: UIColor.whiteText
    ]
  }
}
