// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import SwiftUI

extension CGFloat {
  public static var activeVoiceCountFontSize: Self { 12 }
  public static var buttonFontSize: Self { 20 }
  public static var changeFontSize: Self { 15 }
  public static var copyrightFontSize: Self { 14 }
  public static var effectsControlFontSize: Self { 15 }
  public static var effectsTitleFontSize: Self { 15 }
  public static var footerFontSize: Self { 15 }
  public static var infoBarStatusSize: Self { 20 }
  public static var navigationTitleFontSize: Self { 48 }
  public static var presetEditorFontSize: Self { 18 }
  public static var settingsControlFontSize: Self { 18 }
  public static var settingsDescriptionFontSize: Self { 14 }
  public static var soundFontEditorFontSize: Self { 18 }
  public static var subtitleFontSize: Self { 35 }
  public static var tagsEditorFontSize: Self { 18 }
  public static var tutorialBodyFontSize: Self { 18 }
  public static var tutorialGistFontSize: Self { 22 }
  public static var tutorialTitleFontSize: Self { 48 }
  public static var versionFontSize: Self { 18 }
  public static var toastLabelFontSize: Self { 20 }

  public var appFont: Font { Font.custom(Font.customFontName, size: self) }
}

extension Font {
  public static var applicationFontName: String { "Eurostile" }
  public static var customFontName: String { "\(applicationFontName)Regular" }

  public static var body: Font {
    installApplicationFont()
    return Font.custom(Font.customFontName, size: 20)
  }

  public static var activeVoiceCount: Font { CGFloat.activeVoiceCountFontSize.appFont }
  public static var button: Font { CGFloat.buttonFontSize.appFont }
  public static var change: Font { CGFloat.changeFontSize.appFont }
  public static var copyright: Font { CGFloat.copyrightFontSize.appFont }
  public static var effectsControl: Font { CGFloat.effectsControlFontSize.appFont }
  public static var effectsTitle: Font { CGFloat.effectsTitleFontSize.appFont }
  public static var footer: Font { CGFloat.footerFontSize.appFont }
  public static var navigationTitle: Font { CGFloat.navigationTitleFontSize.appFont }
  public static var presetEditor: Font { CGFloat.presetEditorFontSize.appFont }
  public static var settings: Font { CGFloat.settingsControlFontSize.appFont }
  public static var settingsDescription: Font { CGFloat.settingsDescriptionFontSize.appFont }
  public static var soundFontEditor: Font { CGFloat.soundFontEditorFontSize.appFont }
  public static var status: Font { CGFloat.infoBarStatusSize.appFont }
  public static var tagsEditor: Font { CGFloat.tagsEditorFontSize.appFont }
  public static var tutorialBody: Font { CGFloat.tutorialBodyFontSize.appFont }
  public static var tutorialGist: Font { CGFloat.tutorialGistFontSize.appFont }
  public static var tutorialTitle: Font { CGFloat.tutorialTitleFontSize.appFont }
  public static var version: Font { CGFloat.versionFontSize.appFont }
  public static var toastLabel: Font { CGFloat.toastLabelFontSize.appFont }
}

extension Color {
  public static var listHeaderForeground: Color { Color.gray.mix(with: .black, by: 0.25) }
  public static var presetsHeaderForeground: Color { Color.gray.mix(with: .black, by: 0.30) }
}
