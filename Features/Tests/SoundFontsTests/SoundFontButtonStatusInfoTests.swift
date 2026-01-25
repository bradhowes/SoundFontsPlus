// Copyright © 2025 Brad Howes. All rights reserved.

import BaseSupport
import DependenciesTestSupport
import FeatureSupport
import Models
import SnapshotTesting
import Testing
import TestSupport

@testable import SoundFonts

@Suite(
  .snapshots(record: .failed)
)
@MainActor
struct SoundFontButtonStatusInfoTests {

  struct MockBookmark: Bookmarker {
    var cloudState: Bookmark.CloudState
    var isAvailable: Bool
  }

  @Test
  func tagValue() throws {
    #expect(SoundFontButtonStatusInfoTag.value(for: nil) == .invalidBookmark)
    #expect(
      SoundFontButtonStatusInfoTag.value(
        for: MockBookmark(cloudState: .local, isAvailable: true)
      ) == .localIsAvailable
    )
    #expect(
      SoundFontButtonStatusInfoTag.value(
        for: MockBookmark(cloudState: .local, isAvailable: false)
      ) == .localIsMissing
    )
    #expect(
      SoundFontButtonStatusInfoTag.value(
        for: MockBookmark(cloudState: .inCloud, isAvailable: false)
      ) == .cloudIsMissing
    )
    #expect(
      SoundFontButtonStatusInfoTag.value(
        for: MockBookmark(cloudState: .inCloud, isAvailable: true)
      ) == .cloudIsMissing
    )
    #expect(
      SoundFontButtonStatusInfoTag.value(
        for: MockBookmark(cloudState: .downloading, isAvailable: false)
      ) == .cloudIsDownloading
    )
    #expect(
      SoundFontButtonStatusInfoTag.value(
        for: MockBookmark(cloudState: .downloading, isAvailable: true)
      ) == .cloudIsDownloading
    )
    #expect(
      SoundFontButtonStatusInfoTag.value(
        for: MockBookmark(cloudState: .downloaded, isAvailable: false)
      ) == .cloudIsDownloaded
    )
    #expect(
      SoundFontButtonStatusInfoTag.value(
        for: MockBookmark(cloudState: .downloaded, isAvailable: true)
      ) == .cloudIsDownloaded
    )
    #expect(
      SoundFontButtonStatusInfoTag.value(
        for: MockBookmark(cloudState: .downloadError, isAvailable: false)
      ) == .invalidBookmark
    )
    #expect(
      SoundFontButtonStatusInfoTag.value(
        for: MockBookmark(cloudState: .downloadError, isAvailable: true)
      ) == .invalidBookmark
    )
    #expect(
      SoundFontButtonStatusInfoTag.value(
        for: MockBookmark(cloudState: .unknown, isAvailable: false)
      ) == .invalidBookmark
    )
    #expect(
      SoundFontButtonStatusInfoTag.value(
        for: MockBookmark(cloudState: .unknown, isAvailable: true)
      ) == .invalidBookmark
    )
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
          action: .delegate(.selectSoundFont(info, available: true)),
          imageName: "circle.fill",
          color: .black
        )
    )
    #expect(
      SoundFontButtonStatusInfoTag.invalidBookmark.statusInfo(info) ==
        .init(
          action: .delegate(.selectSoundFont(info, available: true)),
          imageName: "exclamationmark.circle",
          color: .red
        )
    )
    #expect(
      SoundFontButtonStatusInfoTag.localIsAvailable.statusInfo(info) ==
        .init(
          action: .delegate(.selectSoundFont(info, available: true)),
          imageName: "link",
          color: .accentColor.opacity(0.5)
        )
    )
    #expect(
      SoundFontButtonStatusInfoTag.localIsMissing.statusInfo(info) ==
        .init(
          action: .delegate(.alertMissingFile(info)),
          imageName: "exclamationmark.circle",
          color: .yellow
        )
    )
    #expect(
      SoundFontButtonStatusInfoTag.cloudIsDownloaded.statusInfo(info) ==
        .init(
          action: .delegate(.selectSoundFont(info, available: true)),
          imageName: "icloud",
          color: .accentColor.opacity(0.5)
        )
    )
    #expect(
      SoundFontButtonStatusInfoTag.cloudIsDownloading.statusInfo(info) ==
        .init(
          action: .statusInfoChanged(.cloudIsDownloading),
          imageName: "icloud.and.arrow.down.fill",
          color: .accentColor.opacity(0.5)
        )
    )
    #expect(
      SoundFontButtonStatusInfoTag.cloudIsMissing.statusInfo(info) ==
        .init(
          action: .downloadFileButtonTapped,
          imageName: "icloud.and.arrow.down",
          color: .yellow
        )
    )
  }
}

extension SoundFontButtonStatusInfo: Equatable {
  public static func == (lhs: SoundFontButtonStatusInfo, rhs: SoundFontButtonStatusInfo) -> Bool {
    lhs.imageName == rhs.imageName && lhs.color == rhs.color
  }
}
