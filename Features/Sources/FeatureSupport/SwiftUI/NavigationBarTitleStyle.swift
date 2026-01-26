// Copyright © 2025 Brad Howes. All rights reserved.

import SwiftUI

public func installApplicationFont() {
  if let url = Bundle.module.url(forResource: Font.applicationFontName, withExtension: ".ttc"),
     UIFont(name: Font.applicationFontName, size: 12) == nil {
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
  }
}

@MainActor
public func navigationBarTitleStyle() {
#if os(iOS)

  // If the app font is not available, attempt to load it manually so that snapshot tests will use it.
  if UIFont(name: "Eurostile", size: 40) == nil {
    installApplicationFont()
  }

  if let big = UIFont(name: Font.applicationFontName, size: 40) {
    UINavigationBar.appearance().largeTitleTextAttributes = [
      .font: big,
      .foregroundColor: UIColor.whiteText
    ]
  }

  if let normal = UIFont(name: Font.applicationFontName, size: 20) {
    UINavigationBar.appearance().titleTextAttributes = [
      .font: normal,
      .foregroundColor: UIColor.whiteText
    ]
  }

#endif // os(iOS)
}
