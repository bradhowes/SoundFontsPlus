// Copyright © 2024 Brad Howes. All rights reserved.

import Foundation
import os

import Dependencies
import Extensions
import SF2ResourceFiles

/// Various error conditions for loading or working with a sound font (SF2) file
public enum SoundFontKindError: Error {
  case invalidKind
  case failedToRead
  case failedToResolveURL
}

/// Indicators for the various types of SoundFont installs
public enum SoundFontKind {

  /// Built-in sound font file that is comes with the app. Holds a URL to a bundle resource
  case builtin(resource: URL)

  /// Sound font file that was installed by the user into the app's working directory on the device where the app is
  /// running. Holds the URL to the SF2 file.
  case installed(file: URL)

  /// Sound font file that was installed by the user but that was *not* copied into the app's working
  /// directory. This could reside on an external disk for instance, or on the iCloud Drive. As such it is possible it
  /// is not currently available.
  case external(bookmark: Bookmark)
}

public extension SoundFontKind {

  /// The URL that points to the data file that defines the SoundFont.
  var url: URL {
    switch self {
    case .builtin(let resource): return resource
    case .installed(let file): return file
    case .external(let bookmark): return bookmark.url
    }
  }

  /// The String representation of the fileURL
  var path: String { return url.path }

  /// True if built-in resource
  var isBuiltin: Bool {
    if case .builtin = self { return true }
    return false
  }

  /// True if added file is a reference
  var isInstalled: Bool {
    if case .installed = self { return true }
    return false
  }

  /// True if added file is a reference to an external file
  var isExternal: Bool {
    if case .external = self { return true }
    return false
  }

  /// True if the file was added by the user
  var wasAddedByUser: Bool { !isBuiltin }

  /// True if the SF2 file should be deleted when removed from the application
  var deletaWhenRemoved: Bool { isInstalled }

  var asLocation: Location {
    switch self {
    case .builtin(let resource): return Location(kind: .builtin, url: resource, raw: nil)
    case .installed(let file): return Location(kind: .installed, url: file, raw: nil)
    case .external(let bookmark): return Location(kind: .external, url: bookmark.url, raw: bookmark.bookmark)
    }
  }
}
