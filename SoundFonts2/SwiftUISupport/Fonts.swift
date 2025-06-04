// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import SwiftUI

extension CGFloat {
  public static var titleFontSize: Self { 48 }
  public static var subtitleFontSize: Self { 35 }
  public static var copyrightFontSize: Self { 14 }
  public static var versionFontSize: Self { 18 }
  public static var effectsTitleFontSize: Self { 17 }
  public static var effectsControlFontSize: Self { 15 }
  public static var buttonFontSize: Self { 20 }
  public static var infoBarStatusSize: Self { 20 }
}

extension Font {
  public static var statusFont: Font { Font.custom("EurostileRegular", size: .infoBarStatusSize) }
  public static var buttonFont: Font { Font.custom("EurostileRegular", size: .buttonFontSize) }
}
