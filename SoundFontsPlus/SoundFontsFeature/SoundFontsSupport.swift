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

  public static func addSoundFonts(urls: [URL]) -> AddSoundFontsStatus? {
    guard !urls.isEmpty else { return nil }
    var good = [URL]()
    var bad = [String]()

    for url in urls {
      do {
        try addSoundFont(url: url, copyFileWhenAdding: true)
        good.append(url)
      } catch let err as NSError {
        let fileName = url.lastPathComponent
        if err.code == NSFileWriteFileExistsError {
          bad.append("\(fileName): already exists")
        } else {
          bad.append("\(fileName): \(err.localizedDescription)")
        }
      } catch {
        let fileName = url.lastPathComponent
        bad.append("\(fileName): \(error.localizedDescription)")
      }
    }
    return .init(good: good, bad: bad)
  }

  static func addSoundFont(url: URL, copyFileWhenAdding: Bool) throws {

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
