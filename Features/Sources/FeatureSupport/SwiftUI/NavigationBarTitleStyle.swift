// Copyright © 2025 Brad Howes. All rights reserved.

import SwiftUI

public func installApplicationFont() {
#if os(iOS)
  if let url = Bundle.module.url(forResource: Font.applicationFontName, withExtension: ".ttc"),
     UIFont(name: Font.applicationFontName, size: 12) == nil {
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
  }
#elseif os(macOS)
  if let url = Bundle.module.url(forResource: Font.applicationFontName, withExtension: ".ttc"),
     NSFont(name: Font.applicationFontName, size: 12) == nil {
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
  }
#endif
}

@MainActor
public func navigationBarTitleStyle() {
#if os(iOS)

  // If the app font is not available, attempt to load it manually so that snapshot tests will use it.
  if UIFont(name: Font.applicationFontName, size: 30) == nil {
    installApplicationFont()
  }

  if let big = UIFont(name: Font.applicationFontName, size: 30) {
    UINavigationBar.appearance().largeTitleTextAttributes = [
      .font: big,
      .foregroundColor: UIColor.selected
    ]
  }

  if let normal = UIFont(name: Font.applicationFontName, size: 20) {
    UINavigationBar.appearance().titleTextAttributes = [
      .font: normal,
      .foregroundColor: UIColor.selected
    ]
  }

#endif // os(iOS)
}
