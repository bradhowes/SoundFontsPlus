// Copyright © 2025 Brad Howes. All rights reserved.

import BaseSupport
import FeatureSupport
import Models
public import SwiftUI

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
  /// Represents a file in the app sandbox (app documents as well as the app bundle). Everything else is
  /// an `Bookmark` which wraps a URL in a security context which grants the user permission to access the
  /// file outside of the app sandbox.
  case internalFile

  case localIsAvailable
  case localIsMissing

  case invalidBookmark

  case cloudIsDownloaded
  case cloudIsDownloading
  case cloudIsMissing

  static func value(for bookmark: Bookmark?) -> Self {
    guard let bookmark else { return .invalidBookmark }

    let urlState = bookmark.urlState
    if !urlState.isUbiquitousItem {
      return urlState.fileExists ? .localIsAvailable : .localIsMissing
    }

    if urlState.ubiquitousItemIsDownloading == true {
      return .cloudIsDownloading
    } else if urlState.ubiquitousItemDownloadingError != nil {
      return .invalidBookmark
    } else {
      switch urlState.ubiquitousItemDownloadingStatus {
      case .current, .downloaded: return .cloudIsDownloaded
      default: return .cloudIsMissing
      }
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
        action: .delegate(.select(info, available: true)),
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
        action: .delegate(.select(info, available: true)),
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
        action: .delegate(.select(info, available: true)),
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
