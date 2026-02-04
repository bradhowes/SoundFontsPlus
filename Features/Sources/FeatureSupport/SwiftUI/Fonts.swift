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

  public static var changeVersionFontSize: Self { 18 }
  public static var changeDescriptionFontSize: Self { 15 }
  public static var toastLabelFontSize: Self { 20 }

  public var appFont: Font {
    installApplicationFont()
    return Font.custom(Font.customFontName, size: self)
  }
}

extension Font {
  public static var applicationFontName: String { "Eurostile" }
  public static var customFontName: String { "\(applicationFontName)Regular" }

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
  public static var toastLabel: Font { CGFloat.toastLabelFontSize.appFont }

  public static var changeVersion: Font { CGFloat.changeVersionFontSize.appFont }
  public static var changeDescription: Font { CGFloat.changeDescriptionFontSize.appFont }
}

extension Color {

  // Need to republish these since assets have only internal access, not public.
  public static var alternateAccentColor: Self { .alternateAccent }
  public static var mainAccentColor: Self { .mainAccent }
  public static var splitViewHandleBackgroundColor: Self { .splitViewHandleBackground }
  public static var panelBackgroundColor: Self { .panelBackground }

  public static var changeDescription: Color { .accentColor }
  public static var listHeaderForeground: Color { Color.gray.mix(with: .black, by: 0.25) }
  public static var presetsHeaderForeground: Color { Color.gray.mix(with: .black, by: 0.30) }

  public static var buttonActive: Color { .teal }
}

public enum ColorTheme {
  case standard

  public var primaryColor: Color {
    switch self {
    case .standard:
      return .accentColor
    }
  }
}
