// Copyright © 2025 Brad Howes. All rights reserved.

import BaseSupport
import DependenciesTestSupport
import FeatureSupport
import Models
import SnapshotTesting
import SQLiteData
import Tagged
import Testing
import TestSupport

@testable public import SoundFonts

@Suite(
  .snapshots(record: .failed)
)
@MainActor
struct SoundFontButtonStatusInfoTests {

  @Test(
    .dependencies {
      $0.urlStateProvider = .constant(
        .init(
          fileExists: false,
          isUbiquitousItem: false,
          ubiquitousItemDownloadingStatus: nil,
          ubiquitousItemIsDownloading: nil,
          ubiquitousItemDownloadingError: nil
        )
      )
    }
  )
  func tagValue() throws {
    #expect(SoundFontButtonStatusInfoTag.value(for: nil) == .invalidBookmark)
  }

  @Test(
    .dependencies {
      $0.urlStateProvider = .constant(
        .init(
          fileExists: false,
          isUbiquitousItem: false,
          ubiquitousItemDownloadingStatus: nil,
          ubiquitousItemIsDownloading: nil,
          ubiquitousItemDownloadingError: nil
        )
      )
    }
  )
  func localIsMissing() throws {
    #expect(SoundFontButtonStatusInfoTag.value(for: Bookmark(url: SF2ResourceTag.museScore.url, name: "Foo")) == .localIsMissing)
  }

  @Test(
    .dependencies {
      $0.urlStateProvider = .constant(
        .init(
          fileExists: true,
          isUbiquitousItem: false,
          ubiquitousItemDownloadingStatus: nil,
          ubiquitousItemIsDownloading: nil,
          ubiquitousItemDownloadingError: nil
        )
      )
    }
  )
  func localIsAvailable() throws {
    #expect(SoundFontButtonStatusInfoTag.value(for: Bookmark(url: SF2ResourceTag.museScore.url, name: "Foo")) == .localIsAvailable)
  }

  @Test(
    .dependencies {
      $0.urlStateProvider = .constant(
        .init(
          fileExists: true,
          isUbiquitousItem: true,
          ubiquitousItemDownloadingStatus: .current,
          ubiquitousItemIsDownloading: nil,
          ubiquitousItemDownloadingError: nil
        )
      )
    }
  )
  func cloudIsDownloadedCurrent() throws {
    #expect(SoundFontButtonStatusInfoTag.value(for: Bookmark(url: SF2ResourceTag.museScore.url, name: "Foo")) == .cloudIsDownloaded)
  }

  @Test(
    .dependencies {
      $0.urlStateProvider = .constant(
        .init(
          fileExists: true,
          isUbiquitousItem: true,
          ubiquitousItemDownloadingStatus: .downloaded,
          ubiquitousItemIsDownloading: nil,
          ubiquitousItemDownloadingError: nil
        )
      )
    }
  )
  func cloudIsDownloadedDownloaded() throws {
    #expect(SoundFontButtonStatusInfoTag.value(for: Bookmark(url: SF2ResourceTag.museScore.url, name: "Foo")) == .cloudIsDownloaded)
  }

  @Test(
    .dependencies {
      $0.urlStateProvider = .constant(
        .init(
          fileExists: true,
          isUbiquitousItem: true,
          ubiquitousItemDownloadingStatus: .notDownloaded,
          ubiquitousItemIsDownloading: true,
          ubiquitousItemDownloadingError: nil
        )
      )
    }
  )
  func cloudIsDownloading() throws {
    #expect(SoundFontButtonStatusInfoTag.value(for: Bookmark(url: SF2ResourceTag.museScore.url, name: "Foo")) == .cloudIsDownloading)
  }

  @Test(
    .dependencies {
      $0.urlStateProvider = .constant(
        .init(
          fileExists: true,
          isUbiquitousItem: true,
          ubiquitousItemDownloadingStatus: .notDownloaded,
          ubiquitousItemIsDownloading: nil,
          ubiquitousItemDownloadingError: .init()
        )
      )
    }
  )
  func cloudDownloadFailed() throws {
    #expect(SoundFontButtonStatusInfoTag.value(for: Bookmark(url: SF2ResourceTag.museScore.url, name: "Foo")) == .invalidBookmark)
  }

  @Test
  func tagAvailable() async throws {
    #expect(SoundFontButtonStatusInfoTag.internalFile.available == true)
    #expect(SoundFontButtonStatusInfoTag.invalidBookmark.available == false)
    #expect(SoundFontButtonStatusInfoTag.localIsMissing.available == false)
    #expect(SoundFontButtonStatusInfoTag.localIsAvailable.available == true)
    #expect(SoundFontButtonStatusInfoTag.cloudIsMissing.available == false)
    #expect(SoundFontButtonStatusInfoTag.cloudIsDownloaded.available == true)
    #expect(SoundFontButtonStatusInfoTag.cloudIsDownloading.available == false)
  }

  @Test
  func tagStatusInfo() async throws {
    let info: SoundFontInfo = .init(
      id: 1,
      displayName: "Foo",
      kind: .builtin,
      location: .init("1".utf8)
    )
    #expect(
      SoundFontButtonStatusInfoTag.internalFile.statusInfo(info) ==
        .init(
          action: .delegate(.select(info, available: true)),
          imageName: "circle.fill",
          color: .clear
        )
    )
    #expect(
      SoundFontButtonStatusInfoTag.invalidBookmark.statusInfo(info) ==
        .init(
          action: .delegate(.select(info, available: true)),
          imageName: "exclamationmark.circle",
          color: .red
        )
    )
    #expect(
      SoundFontButtonStatusInfoTag.localIsAvailable.statusInfo(info) ==
        .init(
          action: .delegate(.select(info, available: true)),
          imageName: "link",
          color: .mainAccentColor.opacity(0.5)
        )
    )
    #expect(
      SoundFontButtonStatusInfoTag.localIsMissing.statusInfo(info) ==
        .init(
          action: .delegate(.alertMissingFile(info)),
          imageName: "exclamationmark.circle",
          color: .alternateAccentColor
        )
    )
    #expect(
      SoundFontButtonStatusInfoTag.cloudIsDownloaded.statusInfo(info) ==
        .init(
          action: .delegate(.select(info, available: true)),
          imageName: "icloud",
          color: .mainAccentColor.opacity(0.5)
        )
    )
    #expect(
      SoundFontButtonStatusInfoTag.cloudIsDownloading.statusInfo(info) ==
        .init(
          action: .statusInfoChanged(.cloudIsDownloading),
          imageName: "icloud.and.arrow.down.fill",
          color: .mainAccentColor.opacity(0.5)
        )
    )
    #expect(
      SoundFontButtonStatusInfoTag.cloudIsMissing.statusInfo(info) ==
        .init(
          action: .downloadFileButtonTapped,
          imageName: "icloud.and.arrow.down",
          color: .alternateAccentColor
        )
    )
  }
}

extension SoundFontButtonStatusInfo: Equatable {
  public static func == (lhs: SoundFontButtonStatusInfo, rhs: SoundFontButtonStatusInfo) -> Bool {
    lhs.imageName == rhs.imageName && lhs.color == rhs.color
  }
}
