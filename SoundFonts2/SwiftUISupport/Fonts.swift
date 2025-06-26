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
  public static var settingsControlFontSize: Self { 18 }
  public static var soundFontEditorFontSize: Self { 18 }
  public static var presetEditorFontSize: Self { 18 }
  public static var tagsEditorFontSize: Self { 18 }
  public static var buttonFontSize: Self { 20 }
  public static var infoBarStatusSize: Self { 20 }
}

extension Font {
  public static var status: Font { Font.custom("EurostileRegular", size: .infoBarStatusSize) }
  public static var button: Font { Font.custom("EurostileRegular", size: .buttonFontSize) }
  public static var effectsControl: Font { Font.custom("EurostileRegular", size: .effectsControlFontSize) }
  public static var effectsTitle: Font { Font.custom("EurostileRegular", size: 15) }
  public static var navigationTitle: Font { Font.custom("EurostileRegular", size: .titleFontSize) }
  public static var settings: Font { Font.custom("EurostileRegular", size: .settingsControlFontSize) }
  public static var soundFontEditor: Font { Font.custom("EurostileRegular", size: .soundFontEditorFontSize) }
  public static var presetEditor: Font { Font.custom("EurostileRegular", size: .presetEditorFontSize) }
  public static var tagsEditor: Font { Font.custom("EurostileRegular", size: .tagsEditorFontSize) }
}
