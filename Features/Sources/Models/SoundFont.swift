// Copyright © 2024 Brad Howes. All rights reserved.

import AVFoundation
import ComposableArchitecture
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
    public var visible: Bool = true // NOT USED

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
      let name = tag?.name ?? "All"
      let predicate: Predicate<SoundFont> = #Predicate { $0.tags.contains { $0.name == name } }
      return FetchDescriptor<SoundFont>(predicate: predicate,
                                        sortBy: [SortDescriptor(\SoundFont.displayName)])
    }
  }
}

public enum SF2FileError: Error {
  case loadFailure(name: String)
}

public extension ModelContext {

  @MainActor
  func addSoundFont(name: String, kind: SoundFontKind) throws -> SoundFont {
    let location = kind.asLocation
    guard let url = location.url else { fatalError("Unexpected nil URL for SoundFont file")}
    var fileInfo = SF2FileInfo(url.path(percentEncoded: false))
    if !fileInfo.load() {
      throw SF2FileError.loadFailure(name: name)
    }

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
  func allSoundFonts() -> [SoundFont] {
    let fetchDescriptor = FetchDescriptor<SoundFont>(sortBy: [SortDescriptor(\.displayName)])
    var found: [SoundFont] = []

    found = (try? fetch(fetchDescriptor)) ?? []
    if found.isEmpty {
      try? addBuiltInSoundFonts()
      found = (try? fetch(fetchDescriptor)) ?? []
    }

    if found.isEmpty {
      fatalError("Failed to install built-in SF2 files.")
    }

    return found
  }

  @MainActor
  func soundFonts(with tag: Tag) -> [SoundFont] {
    let fetchDescriptor = SoundFont.fetchDescriptor(by: tag)
    return (try? fetch(fetchDescriptor)) ?? []
  }

  /// TODO: remove when cascading is fixed
  @MainActor
  func delete(soundFont: SoundFont) {
    @Dependency(\.fileManager) var fileManager

    switch soundFont.kind {
    case .builtin: break
    case .external: break
    case .installed(let url):
      do {
        try fileManager.removeItem(url)
        for (index, path) in FileManager.default.sharedContents.enumerated() {
          print(index, path)
        }
      } catch {
        print("failed to remove \(url) - \(error)")
      }
    }

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
    case .installed: tags.append(ubiquitousTag(.added))
    case .external: tags += [ubiquitousTag(.added), ubiquitousTag(.external)]
    }
    return tags
  }

  struct PickedStatus {
    public let good: Int
    public let bad: [String]

    public init(good: Int, bad: [String]) {
      self.good = good
      self.bad = bad
    }
  }

  @MainActor
  func picked(urls: [URL]) -> PickedStatus {
    var good = 0
    var bad = [String]()

    for url in urls {
      let fileName = url.lastPathComponent
      let displayName = String(fileName[fileName.startIndex..<(fileName.lastIndex(of: ".") ?? fileName.endIndex)])
      let destination = FileManager.default.sharedPath(for: fileName)

      do {
        try FileManager.default.moveItem(at: url, to: destination)
      } catch let err as NSError {
        if err.code != NSFileWriteFileExistsError {
          bad.append(fileName)
          continue
        }
      }

      do {
        _ = try addSoundFont(name: displayName, kind: .installed(file: destination))
      } catch SF2FileError.loadFailure {
        bad.append(fileName)
        continue
      } catch {
        bad.append(fileName)
        continue
      }

      good += 1
    }

    for (index, path) in FileManager.default.sharedContents.enumerated() {
      print(index, path)
    }

    return .init(good: good, bad: bad)
  }
}
