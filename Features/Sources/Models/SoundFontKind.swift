// Copyright © 2024 Brad Howes. All rights reserved.

import Foundation
import os

import Dependencies
import Extensions
import SF2Files


/// Various error conditions for loading or working with a sound font (SF2) file
enum SoundFontKindError: Error {
  case invalidKind
  case failedToRead
  case failedToResolveURL
}

/// There are two types of SoundFont instances in the application: a built-in kind that resides in the app's bundle, and
/// a file kind which comes from an external source.
enum SoundFontKind {

  @Dependency(\.fileManager.sharedDocumentsDirectory) static var sharedDocumentsDirectory

  /// Built-in sound font file that is comes with the app. Holds a URL to a bundle resource
  case builtin(resource: URL)

  /// Sound font file that was installed by the user. Holds the URL to the SF2 file
  case installed(file: URL)

  /// Alternative sound font file that was installed by the user but that was not copied into the app's working
  /// directory. This could reside on an external disk for instance, or on the iCloud Drive.
  case reference(bookmark: Bookmark)

  /// The URL that points to the data file that defines the SoundFont.
  var url: URL {
    switch self {
    case .builtin(let resource): return resource
    case .installed(let file): return file
    case .reference(let bookmark): return bookmark.url
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

  /// True if added file is a reference
  var isReference: Bool {
    if case .reference = self { return true }
    return false
  }

  /// True if the file was added by the user
  var wasAddedByUser: Bool { !isBuiltin }

  /// True if the SF2 file should be deleted when removed from the application
  var deletaWhenRemoved: Bool { isInstalled }
}
