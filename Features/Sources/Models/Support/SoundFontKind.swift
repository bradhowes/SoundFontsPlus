// Copyright © 2025 Brad Howes. All rights reserved.

import BaseSupport
import Dependencies
import Engine
import Foundation
import os
import SF2Resources

/// Indicators for the various types of SoundFont installs
public enum SoundFontKind {

  /// Built-in sound font file that is comes with the app. Holds a URL to a bundle resource
  case builtin(tag: SF2ResourceTag)

  /// Sound font file that was installed by the user into the app's working directory on the device where the app is
  /// running. Holds the URL to the SF2 file.
  case installed(filename: String)

  /// Sound font file that was installed by the user but that was *not* copied into the app's working
  /// directory. This could reside on an external disk for instance, or on the iCloud Drive. As such it is possible it
  /// is not currently available.
  case external(bookmark: Bookmark)

  public init(kind: SoundFont.Kind, location: Data, displayName: String) throws {
    switch kind {
    case .builtin: self = try .builtin(tag: dataToTag(location, displayName: displayName))
    case .installed: self = try .installed(filename: dataToFilename(location, displayName: displayName))
    case .external: self = try .external(bookmark: Bookmark.from(data: location))
    }
  }
}

extension SoundFontKind: Equatable {}

extension SoundFontKind {

  public func data() throws -> (SoundFont.Kind, Data) {
    switch self {
    case .builtin(tag: let tag): return (.builtin, try tagToData(tag))
    case .installed(filename: let filename): return (.installed, try filenameToData(filename))
    case .external(bookmark: let bookmark): return (.external, try bookmark.toData())
    }
  }

  public var description: String {
    switch self {
    case .builtin: return "built-in"
    case .installed: return "installed"
    case .external: return "external link"
    }
  }

  public var path: URL {
    @Dependency(\.fileManager) var fileManager
    switch self {
    case .builtin(tag: let tag): return tag.url
    case .installed(filename: let filename): return fileManager.fontFilePath(filename)
    case .external(bookmark: let bookmark): return bookmark.url
    }
  }

  /// True if built-in resource
  public var isBuiltin: Bool {
    if case .builtin = self { return true }
    return false
  }

  /// True if added file is a reference
  public var isInstalled: Bool {
    if case .installed = self { return true }
    return false
  }

  /// True if added file is a reference to an external file
  public var isExternal: Bool {
    if case .external = self { return true }
    return false
  }

  public var tagIds: [FontTag.ID] {
    var ubiTags: [FontTag.Ubiquitous] = [.all]
    switch self {
    case .builtin: ubiTags.append(.builtIn)
    case .installed: ubiTags += [.added, .device]
    case .external: ubiTags += [.added, .external]
    }
    // TODO: also add active tag?
    return ubiTags.map { $0.id }
  }

  /// True if the file was added by the user
  public var addedByUser: Bool { !isBuiltin }

  /// True if the SF2 file should be deleted when removed from the application
  public var deleteWhenRemoved: Bool { isInstalled }

  public func fileInfo() throws -> SF2FileInfo {
    @Dependency(\.fileManager) var fileManager
    switch self {
    case .builtin(tag: let tag): return try fileInfo(from: tag.url)
    case .installed(filename: let filename): return try fileInfo(from: fileManager.fontFilePath(filename))
    case .external(bookmark: let bookmark): return try fileInfo(from: bookmark.url)
    }
  }

  private func fileInfo(from url: URL) throws -> SF2FileInfo {
    var fileInfo = SF2FileInfo(std.string(url.path(percentEncoded: false)))
    guard fileInfo.load() else {
      throw ModelError.loadFailure(url: url)
    }
    return fileInfo
  }
}

private func dataToUrl(_ data: Data, displayName: String) throws -> URL {
  guard let path = String(data: data, encoding: .utf8),
        let url = URL(string: path, encodingInvalidCharacters: false) else {
    throw ModelError.dataIsNotValidURL(data: data, displayName: displayName)
  }
  return url
}

private func urlToData(_ url: URL) throws -> Data {
  .init(url.absoluteString.utf8)
}

private func dataToFilename(_ data: Data, displayName: String) throws -> String {
  guard let name = String(data: data, encoding: .utf8) else {
    throw ModelError.dataIsNotValidString(data: data, displayName: displayName)
  }
  return name
}

private func filenameToData(_ name: String) throws -> Data {
  .init(name.utf8)
}

private func dataToTag(_ data: Data, displayName: String) throws -> SF2ResourceTag {
  guard let tagStr = String(data: data, encoding: .utf8),
        let tagInt = Int(tagStr),
        let tag = SF2ResourceTag(rawValue: tagInt)
  else {
    throw ModelError.dataIsNotValidTag(data: data, displayName: displayName)
  }
  return tag
}

private func tagToData(_ tag: SF2ResourceTag) throws -> Data {
  .init("\(tag.rawValue)".utf8)
}
