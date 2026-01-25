//
//  StatusInfo.swift
//  SoundFontsPlus
//
//  Created by Brad Howes on 1/25/26.
//


  /**
   Attributes that affect the "accessory" button.
   */
  public struct StatusInfo {
    let action: Action
    let imageName: String
    let color: Color
  }

  @frozen
  public enum StatusInfoTag: Equatable {
    case internalFile
    case invalidBookmark
    case localIsAvailable
    case localIsMissing
    case cloudIsDownloaded
    case cloudIsDownloading
    case cloudIsMissing

    static func value(for bookmark: Bookmark?) -> Self {
      guard let bookmark else { return .invalidBookmark }
      let cloudState = bookmark.cloudState
      switch cloudState {
      case .local:
        return bookmark.isAvailable ? .localIsAvailable : .localIsMissing
        /// Item is on iCloud but not available locally.
      case .inCloud:
        return .cloudIsMissing
      case .downloadRequested:
        return .cloudIsDownloading
      case .downloading:
        return .cloudIsDownloading
      case .downloaded:
        return .cloudIsDownloaded
      case .downloadError:
        return .invalidBookmark
      case .unknown:
        return .invalidBookmark
      }
    }

    var available: Bool {
      switch self {
      case .invalidBookmark, .localIsMissing, .cloudIsMissing, .cloudIsDownloading: return false
      default: return true
      }
    }

    func statusInfo(_ info: SoundFontInfo) -> StatusInfo {
      switch self {
      case .internalFile:
        return .init(
          action: .delegate(.selectSoundFont(info, available: true)),
          imageName: "circle.fill",
          color: .black
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
          color: .accentColor.opacity(0.5)
        )
      case .localIsMissing:
        return .init(
          action: .delegate(.alertMissingFile(info)),
          imageName: "exclamationmark.circle",
          color: .yellow
        )
      case .cloudIsDownloaded:
        return .init(
          action: .delegate(.selectSoundFont(info, available: true)),
          imageName: "icloud",
          color: .accentColor.opacity(0.5)
        )
      case .cloudIsDownloading:
        return .init(
          action: .statusInfoChanged(.cloudIsDownloading),
          imageName: "icloud.and.arrow.down.fill",
          color: .accentColor.opacity(0.5)
        )
      case .cloudIsMissing:
        return .init(
          action: .downloadFileButtonTapped,
          imageName: "icloud.and.arrow.down",
          color: .yellow
        )
      }
    }
  }
