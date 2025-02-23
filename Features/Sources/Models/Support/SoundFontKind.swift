// Copyright © 2024 Brad Howes. All rights reserved.

import Foundation
import os

import Dependencies
import Engine
import Extensions
import SF2ResourceFiles

/// Various error conditions for loading or working with a sound font (SF2) file
public enum SoundFontKindError: Error {
  case invalidKind
  case failedToRead
  case failedToResolveURL
}

/// Indicators for the various types of SoundFont installs
public enum SoundFontKind: Equatable {
  
  /// Built-in sound font file that is comes with the app. Holds a URL to a bundle resource
  case builtin(resource: URL)
  
  /// Sound font file that was installed by the user into the app's working directory on the device where the app is
  /// running. Holds the URL to the SF2 file.
  case installed(file: URL)
  
  /// Sound font file that was installed by the user but that was *not* copied into the app's working
  /// directory. This could reside on an external disk for instance, or on the iCloud Drive. As such it is possible it
  /// is not currently available.
  case external(bookmark: Bookmark)

  init(kind: SoundFont.Kind, location: Data) throws {
    switch kind {
    case .builtin: self = try .builtin(resource: dataToUrl(location))
    case .installed: self = try .installed(file: dataToUrl(location))
    case .external: self = try .external(bookmark: Bookmark.from(data: location))
    }
  }
}

public extension SoundFontKind {

  func data() throws -> (SoundFont.Kind, Data) {
    switch self {
    case .builtin(let url): return (.builtin, try urlToData(url))
    case .installed(let url): return (.builtin, try urlToData(url))
    case .external(let bookmark): return (.external, try bookmark.toData())
    }
  }

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

  var tagIds: [Tag.ID] {
    var ubiTags: [Tag.Ubiquitous] = [.all]
    switch self {
    case .builtin: ubiTags.append(.builtIn)
    case .installed: ubiTags.append(.added)
    case .external: ubiTags += [.added, .external]
    }
    // TODO: also add active tag?
    return ubiTags.map { $0.id }
  }

  /// True if the file was added by the user
  var addedByUser: Bool { !isBuiltin }

  /// True if the SF2 file should be deleted when removed from the application
  var deletaWhenRemoved: Bool { isInstalled }

  func fileInfo() throws -> SF2FileInfo {
    switch self {
    case .builtin(let url): return try fileInfo(from: url)
    case .installed(let url): return try fileInfo(from: url)
    case .external(let bookmark): return try fileInfo(from: bookmark.url)
    }
  }

  private func fileInfo(from url: URL) throws -> SF2FileInfo {
    var fileInfo = SF2FileInfo(url.path(percentEncoded: false))
    guard fileInfo.load() else {
      throw ModelError.loadFailure(name: url.absoluteString)
    }
    return fileInfo
  }
}

private func dataToUrl(_ data: Data) throws -> URL {
  guard let url = URL(dataRepresentation: data, relativeTo: nil, isAbsolute: true) else {
    throw ModelError.dataIsNotValidURL(data: data)
  }
  return url
}

private func urlToData(_ url: URL) throws -> Data {
  guard let data = url.absoluteString.data(using: .utf8) else {
    throw ModelError.urlIsNotValidData(url: url)
  }
  return data
}
