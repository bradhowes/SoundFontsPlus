// Copyright © 2025 Brad Howes. All rights reserved.

public import BaseSupport
import Dependencies
public import Engine
public import Foundation
import os
public import SF2Resources

/**
 Indicators for the various types of SoundFont file locations. These mirror the values found in `SoundFont.Kind`, and the 1-1
 relationship must be maintained between the two.
 */
public enum SoundFontKind {

  /// Built-in sound font file that is comes with the app. Holds a enum value that indicates the resource name and URL in the app
  /// bundle where it resides.
  case builtin(tag: SF2ResourceTag)

  /// Sound font file that was installed by the user into the app groupd directory on the device where the app is
  /// running. Holds the file name with extension. The full path to the file is always generated using
  /// `FileManagerClient.fontFilePath`.
  case installed(filename: String)

  /// Sound font file that was installed by the user but that was *not* copied into the app's working
  /// directory. This could reside on an external disk for instance, or on the iCloud Drive. As such it is always possible for it
  /// to not be readily available.
  case external(bookmark: Bookmark)

  /**
   Create a new instance value.

   - parameter kind: the mirror value from the ``SoundFont`` model.
   - parameter location: location information encoded in a `Data` value.
   - parameter displayName: the display name of the SoundFont (only for logging)
   - throws a ``ModelError`` exception if unable to decode the `location` value or if `kind` has an unknown value.
   */
  public init(kind: SoundFont.Kind, location: Data, displayName: String) throws {
    switch kind {
    case .builtin: self = try .builtin(tag: dataToTag(location, displayName: displayName))
    case .installed: self = try .installed(filename: dataToFilename(location, displayName: displayName))
    case .external: self = try .external(bookmark: Bookmark.from(data: location))
    default: throw ModelError.unknownSoundFontKind(value: kind.rawValue)
    }
  }
}

extension SoundFontKind: Equatable {}

extension SoundFontKind {

  /**
   Destructure the enum into a `SoundFont.Kind` value and a `Data` value that encodes the location of the SF2 file.

   - returns 2-tuple value to be used when writing to the ``SoundFont`` database table.
   */
  public func data() throws -> (SoundFont.Kind, Data) {
    switch self {
    case .builtin(tag: let tag): return (.builtin, try tagToData(tag))
    case .installed(filename: let filename): return (.installed, try filenameToData(filename))
    case .external(bookmark: let bookmark): return (.external, try bookmark.toData())
    }
  }

  /// - returns: a textual description of the enum value
  public var description: String {
    switch self {
    case .builtin: return "built-in"
    case .installed: return "installed"
    case .external: return "external link"
    }
  }

  /// - returns: a complete URL that points to the SF2 file
  public var url: URL {
    @Dependency(\.fileManager) var fileManager
    switch self {
    case .builtin(tag: let tag): return tag.url
    case .installed(filename: let filename): return fileManager.fontFilePath(filename)
    case .external(bookmark: let bookmark): return bookmark.url
    }
  }

  /// - returns: True if built-in resource
  public var isBuiltin: Bool {
    if case .builtin = self { return true }
    return false
  }

  /// - returns: True if added file is a reference
  public var isInstalled: Bool {
    if case .installed = self { return true }
    return false
  }

  /// - returns: True if added file is a reference to an external file
  public var isExternal: Bool {
    if case .external = self { return true }
    return false
  }

  /// - returns: A list of `Tag.ID` values to associate with when adding a new file.
  public var tagIds: [Tag.ID] {
    var ubiTags: [Tag.Ubiquitous] = [.all]
    switch self {
    case .builtin: ubiTags.append(.builtIn)
    case .installed: ubiTags += [.added, .device]
    case .external: ubiTags += [.added, .external]
    }
    // TODO: also add active tag?
    return ubiTags.map { $0.id }
  }

  /// - returns: True if the file was added by the user
  public var addedByUser: Bool { !isBuiltin }

  /// - returns: True if the SF2 file should be deleted when removed from the application
  public var deleteWhenRemoved: Bool { isInstalled }

  /// - returns a `SF2FileInfo` instance that can return meta data associated with the SF2 file.
  public func fileInfo() throws -> SF2FileInfo {
    var fileInfo = SF2FileInfo(std.string(url.path(percentEncoded: false)))
    guard fileInfo.load() else { throw ModelError.loadFailure(url: url) }
    return fileInfo
  }
}

private func dataToUrl(_ data: Data, displayName: String) throws -> URL {
  guard
    let path = String(data: data, encoding: .utf8),
    let url = URL(string: path, encodingInvalidCharacters: false)
  else {
    throw ModelError.dataIsNotValidURL(data: data, displayName: displayName)
  }
  return url
}

private func urlToData(_ url: URL) throws -> Data { .init(url.absoluteString.utf8) }

private func dataToFilename(_ data: Data, displayName: String) throws -> String {
  guard
    let name = String(data: data, encoding: .utf8)
  else {
    throw ModelError.dataIsNotValidString(data: data, displayName: displayName)
  }
  return name
}

private func filenameToData(_ name: String) throws -> Data { .init(name.utf8) }

private func dataToTag(_ data: Data, displayName: String) throws -> SF2ResourceTag {
  guard
    let tagStr = String(data: data, encoding: .utf8),
    let tagInt = Int(tagStr),
    let tag = SF2ResourceTag(rawValue: tagInt)
  else {
    throw ModelError.dataIsNotValidTag(data: data, displayName: displayName)
  }
  return tag
}

private func tagToData(_ tag: SF2ResourceTag) throws -> Data { .init("\(tag.rawValue)".utf8) }
