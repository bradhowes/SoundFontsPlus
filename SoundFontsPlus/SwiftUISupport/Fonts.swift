// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import SwiftUI

extension CGFloat {
  public static var activeVoiceCountFontSize: Self { 12 }
  public static var buttonFontSize: Self { 20 }
  public static var copyrightFontSize: Self { 14 }
  public static var effectsControlFontSize: Self { 15 }
  public static var effectsTitleFontSize: Self { 15 }
  public static var infoBarStatusSize: Self { 20 }
  public static var presetEditorFontSize: Self { 18 }
  public static var settingsControlFontSize: Self { 18 }
  public static var soundFontEditorFontSize: Self { 18 }
  public static var subtitleFontSize: Self { 35 }
  public static var tagsEditorFontSize: Self { 18 }
  public static var titleFontSize: Self { 48 }
  public static var versionFontSize: Self { 18 }
  public static var changeFontSize: Self { 15 }
  public static var tutorialGistFontSize: Self { 22 }
  public static var tutorialBodyFontSize: Self { 18 }

  public var font: Font { Font.custom("EurostileRegular", size: self) }
}

extension Font {
  public static var button: Font { CGFloat.buttonFontSize.font }
  public static var activeVoiceCount: Font { CGFloat.activeVoiceCountFontSize.font }
  public static var effectsControl: Font { CGFloat.effectsControlFontSize.font }
  public static var effectsTitle: Font { CGFloat.effectsTitleFontSize.font }
  public static var navigationTitle: Font { CGFloat.titleFontSize.font }
  public static var presetEditor: Font { CGFloat.presetEditorFontSize.font }
  public static var settings: Font { CGFloat.settingsControlFontSize.font }
  public static var soundFontEditor: Font { CGFloat.soundFontEditorFontSize.font }
  public static var status: Font { CGFloat.infoBarStatusSize.font }
  public static var tagsEditor: Font { CGFloat.tagsEditorFontSize.font }
  public static var title: Font { CGFloat.titleFontSize.font }
  public static var version: Font { CGFloat.versionFontSize.font }
  public static var change: Font { CGFloat.changeFontSize.font }
  public static var tutorialGist: Font { CGFloat.tutorialGistFontSize.font }
  public static var tutorialBody: Font { CGFloat.tutorialBodyFontSize.font }
}
