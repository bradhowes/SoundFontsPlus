// Copyright © 2024 Brad Howes. All rights reserved.

import AVFoundation
import Foundation
import SwiftData

import Engine
import SF2Files

public typealias SoundFont = SchemaV1.SoundFont

extension SchemaV1 {

  @Model
  public final class SoundFont {
    public var location: Location = Location(kind: .builtin, url: nil, raw: nil)
    @Relationship(deleteRule: .cascade, inverse: \Preset.owner) public var presets: [Preset] = []
    public var displayName: String = ""
    @Relationship(inverse: \Tag.tagged) public var tags: [Tag] = []
    public var visible: Bool = true

    public var embeddedName: String = ""
    public var embeddedComment: String = ""
    public var embeddedAuthor: String = ""
    public var embeddedCopyright: String = ""

    public var orderedPresets: [Preset] {
      self.presets.sorted(by: { $0.index < $1.index })
    }

    public init(location: Location, name: String) {
      self.location = location
      self.displayName = name
    }

    var kind: SoundFontKind {
      switch location.kind {
      case .builtin: 
        return .builtin(resource: location.url!)
      case .installed:
        return .installed(file: location.url!)
      case .external:
        guard let bookmark = try? Bookmark.from(data: location.raw!) else {
          fatalError("invalid Bookmark")
        }
        return .external(bookmark: bookmark)
      }
    }
  }
}

public extension ModelContext {

  @MainActor
  func createSoundFont(name: String, kind: SoundFontKind) throws -> SoundFont {
    let location = kind.asLocation
    guard let url = location.url else { fatalError("Unexpected nil URL for SoundFont file")}
    var fileInfo = SF2FileInfo(url.path(percentEncoded: false))
    fileInfo.load()

    let soundFont = SoundFont(location: location, name: name)
    insert(soundFont)
    soundFont.embeddedName = String(fileInfo.embeddedName())
    soundFont.embeddedAuthor = String(fileInfo.embeddedAuthor())
    soundFont.embeddedComment = String(fileInfo.embeddedComment())
    soundFont.embeddedCopyright = String(fileInfo.embeddedCopyright())
    
    for index in 0..<fileInfo.size() {
      let presetInfo = fileInfo[index]
      let preset: Preset = .init(owner: soundFont, index: index, name: String(presetInfo.name()))
      soundFont.presets.append(preset)
    }

    try save()

    soundFont.tags = try tagsFor(kind: kind)
    soundFont.tags.forEach { $0.tag(soundFont: soundFont) }

    try save()

    return soundFont
  }

  @MainActor
  func createSoundFont(resourceTag: SF2FileTag) throws -> SoundFont {
    var fileInfo = SF2FileInfo(resourceTag.url.path(percentEncoded: false))
    fileInfo.load()
    print("size:", fileInfo.size())
    let kind: SoundFontKind = .builtin(resource: resourceTag.url)
    return try createSoundFont(name: resourceTag.name, kind: kind)
  }

  @MainActor
  func soundFonts() throws -> [SoundFont] {
    return try fetch(FetchDescriptor<SoundFont>(sortBy: [SortDescriptor(\.displayName)]))
  }

  /// TODO: remove when cascading is fixed
  @MainActor
  func delete(soundFont: SoundFont) {
    for preset in soundFont.presets {
      self.delete(preset: preset)
    }

    self.delete(soundFont)
  }

  @MainActor
  fileprivate func tagsFor(kind: SoundFontKind) throws -> [Tag] {
    var tags = [try ubiquitousTag(.all)]
    switch kind {
    case .builtin: tags.append(try ubiquitousTag(.builtIn))
    case .installed: tags.append(try ubiquitousTag(.user))
    case .external: tags += [try ubiquitousTag(.user), try ubiquitousTag(.external)]
    }
    return tags
  }
}
