// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import Engine
import SwiftUI

enum SoundFontsSupport {

  static public func generateTagsList(from tags: [FontTag]) -> String {
    tags.map(\.displayName).sorted().joined(separator: ", ")
  }

  public struct AddSoundFontsStatus {
    public let good: [URL]
    public let bad: [String]

    public init(good: [URL], bad: [String]) {
      self.good = good
      self.bad = bad
    }
  }

  static func addSoundFont(url: URL, copyFileWhenAdding: Bool) throws -> String {
    // Attempt to load the file to see if there are any errors
    var fileInfo = SF2FileInfo(url.path(percentEncoded: false))
    fileInfo.load()

    // Use the file name for the initial display name. Users can change to other embedded values via editor.
    let displayName = String(url.lastPathComponent.withoutExtension)

    let location: SoundFontKind
    if copyFileWhenAdding {
      location = .installed(file: try copyToSharedFolder(source: url))
    } else {
      location = .external(bookmark: Bookmark(url: url, name: displayName))
    }

    try SoundFont.add(displayName: displayName, soundFontKind: location)

    return displayName
  }

  static func copyToSharedFolder(source: URL) throws -> URL {
    let accessing = source.startAccessingSecurityScopedResource()
    defer { if accessing { source.stopAccessingSecurityScopedResource() } }

    let destination = FileManager.default.sharedPath(for: source.lastPathComponent)
    try FileManager.default.copyItem(at: source, to: destination)

    return destination
  }
}

extension String {
  var withoutExtension: Substring { self[self.startIndex..<(self.lastIndex(of: ".") ?? self.endIndex)] }
}
