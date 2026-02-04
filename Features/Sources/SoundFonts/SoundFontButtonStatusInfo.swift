// Copyright © 2025 Brad Howes. All rights reserved.

import BaseSupport
import Models
import SwiftUI

/**
 Attributes that affect the "accessory" button of a ``SoundFontButton``
 */
public struct SoundFontButtonStatusInfo {
  let action: SoundFontButton.Action
  let imageName: String
  let color: Color

  public init(action: SoundFontButton.Action, imageName: String, color: Color) {
    self.action = action
    self.imageName = imageName
    self.color = color
  }
}

@frozen
public enum SoundFontButtonStatusInfoTag: Equatable {
  case internalFile
  case invalidBookmark
  case localIsAvailable
  case localIsMissing
  case cloudIsDownloaded
  case cloudIsDownloading
  case cloudIsMissing

  static func value(for bookmark: Bookmarker?) -> Self {
    guard let bookmark else { return .invalidBookmark }
    let cloudState = bookmark.cloudState
    switch cloudState {
    case .local: return bookmark.isAvailable ? .localIsAvailable : .localIsMissing
      /// Item is on iCloud but not available locally.
    case .inCloud: return .cloudIsMissing
    case .downloading: return .cloudIsDownloading
    case .downloaded: return .cloudIsDownloaded
    case .downloadError: return .invalidBookmark
    case .unknown: return .invalidBookmark
    }
  }

  var available: Bool {
    switch self {
    case .invalidBookmark, .localIsMissing, .cloudIsMissing, .cloudIsDownloading: return false
    default: return true
    }
  }

  func statusInfo(_ info: SoundFontInfo) -> SoundFontButtonStatusInfo {
    switch self {
    case .internalFile:
      return .init(
        action: .delegate(.selectSoundFont(info, available: true)),
        imageName: "circle.fill",
        color: .clear
      )
    case .invalidBookmark:
      return .init(
        action: .delegate(.alertInvalidBookmark(info)),
        imageName: "exclamationmark.circle",
        color: .red
      )
    case .localIsAvailable:
      return .init(
        action: .delegate(.selectSoundFont(info, available: true)),
        imageName: "link",
        color: .mainAccentColor.opacity(0.5)
      )
    case .localIsMissing:
      return .init(
        action: .delegate(.alertMissingFile(info)),
        imageName: "exclamationmark.circle",
        color: .alternateAccentColor
      )
    case .cloudIsDownloaded:
      return .init(
        action: .delegate(.selectSoundFont(info, available: true)),
        imageName: "icloud",
        color: .mainAccentColor.opacity(0.5)
      )
    case .cloudIsDownloading:
      return .init(
        action: .statusInfoChanged(.cloudIsDownloading),
        imageName: "icloud.and.arrow.down.fill",
        color: .mainAccentColor.opacity(0.5)
      )
    case .cloudIsMissing:
      return .init(
        action: .downloadFileButtonTapped,
        imageName: "icloud.and.arrow.down",
        color: .alternateAccentColor
      )
    }
  }
}
