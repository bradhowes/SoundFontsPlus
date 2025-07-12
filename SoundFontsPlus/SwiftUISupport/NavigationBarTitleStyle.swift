import SwiftUI

public func navigationBarTitleStyle() {
  UINavigationBar.appearance().largeTitleTextAttributes = [
    .font : UIFont(name: "Eurostile", size: 48)!,
    .foregroundColor : UIColor.whiteText // accentText
  ]

  UINavigationBar.appearance().titleTextAttributes = [
    .font : UIFont(name: "Eurostile", size: 20)!,
    .foregroundColor : UIColor.whiteText // accentText
  ]
}
