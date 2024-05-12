// Copyright © 2024 Brad Howes. All rights reserved.

import AVFoundation
import Foundation
import SwiftData

import Engine
import SF2ResourceFiles

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
    
    /// Computed property to obtain the SoundFontKind from the properties of a SoundFont model.
    public var kind: SoundFontKind {
      switch location.kind {
      case .builtin: 
        return .builtin(resource: location.url!)
      case .installed:
        return .installed(file: location.url!)
      case .external:
        guard let bookmark = try? Bookmark.from(data: location.raw!) else {
          // FIXME: properly handle this
          fatalError("invalid Bookmark")
        }
        return .external(bookmark: bookmark)
      }
    }

    /**
     Create a FetchDescriptor that returns all SoundFont entities which belong to the given Tag entity.

     - parameter tag: the Tag to filter with
     - returns: the FetchDescriptor to assign to a Query
     */
    public static func fetchDescriptor(by tag: Tag?) -> FetchDescriptor<SoundFont> {
      let name = tag?.name ?? ""
      let predicate: Predicate<SoundFont>? = name.isEmpty ? nil : (#Predicate { $0.tags.contains { $0.name == name } })
      return FetchDescriptor<SoundFont>(predicate: predicate,
                                        sortBy: [SortDescriptor(\SoundFont.displayName)])
    }
  }
}

public extension ModelContext {

  @MainActor
  func addSoundFont(name: String, kind: SoundFontKind) throws -> SoundFont {
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
  func addSoundFont(resourceTag: SF2ResourceFileTag) throws -> SoundFont {
    var fileInfo = SF2FileInfo(resourceTag.url.path(percentEncoded: false))
    fileInfo.load()
    print("size:", fileInfo.size())
    let kind: SoundFontKind = .builtin(resource: resourceTag.url)
    return try addSoundFont(name: resourceTag.name, kind: kind)
  }

  @MainActor
  func addBuiltInSoundFonts() throws {
    for tag in SF2ResourceFileTag.allCases {
      _ = try addSoundFont(resourceTag: tag)
    }
  }

  @MainActor
  func soundFonts() -> [SoundFont] {
    let fetchDescriptor = FetchDescriptor<SoundFont>(sortBy: [SortDescriptor(\.displayName)])
    var found: [SoundFont] = []

    do {
      found = try fetch(fetchDescriptor)
      if found.isEmpty {
        try addBuiltInSoundFonts()
        found = try fetch(fetchDescriptor)
      }
    } catch {
    }

    if found.isEmpty {
      fatalError("Failed to install built-in SF2 files.")
    }

    return found
  }

  @MainActor
  func soundFonts(with tag: Tag) -> [SoundFont] {
    let tagName = tag.name
    let fetchDescriptor: FetchDescriptor<SoundFont> = .init(
      predicate: #Predicate { $0.tags.contains { $0.name == tagName } },
      sortBy: [SortDescriptor(\SoundFont.displayName)]
    )

    let found = try? fetch(fetchDescriptor)
    return found ?? []
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
    var tags = [ubiquitousTag(.all)]
    switch kind {
    case .builtin: tags.append(ubiquitousTag(.builtIn))
    case .installed: tags.append(ubiquitousTag(.user))
    case .external: tags += [ubiquitousTag(.user), ubiquitousTag(.external)]
    }
    return tags
  }
}
