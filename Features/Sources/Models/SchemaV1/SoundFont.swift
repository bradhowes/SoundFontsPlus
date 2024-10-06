// Copyright © 2024 Brad Howes. All rights reserved.

import AVFoundation
import ComposableArchitecture
import Dependencies
import Foundation
import SwiftData

import Engine
import SF2ResourceFiles

extension SchemaV1 {

  public struct SoundFontPresetId: Codable {
    public let soundFont: UUID
    public let preset: Int
  }

  @Model
  public final class SoundFontModel {
    public var uuid: UUID
    public var displayName: String
    public var location: Location

    @Relationship(deleteRule: .cascade)
    public var presets: [PresetModel]

    @Relationship(inverse: \TagModel.tagged)
    public var tags: [TagModel]

    public var info: SoundFontInfoModel

    public var orderedPresets: [PresetModel] {
      presets.sorted(by: { $0.soundFontPresetId.preset < $1.soundFontPresetId.preset })
    }

    public init(
      uuid: UUID,
      name: String,
      location: Location,
      info: SoundFontInfoModel
    ) {
      self.uuid = uuid
      self.displayName = name
      self.location = location
      self.presets = []
      self.tags = []
      self.info = info
    }

    public func kind() throws -> SoundFontKind {
      switch location.kind {
      case .builtin:
        guard let url = location.url else {
          throw ModelError.invalidLocation(name: self.displayName)
        }
        return .builtin(resource: url)
      case .installed:
        guard let url = location.url else {
          throw ModelError.invalidLocation(name: self.displayName)
        }
        return .installed(file: url)
      case .external:
        guard let data = location.raw else {
          throw ModelError.invalidLocation(name: self.displayName)
        }
        do {
          return .external(bookmark: try Bookmark.from(data: data))
        } catch {
          throw ModelError.invalidBookmark(name: self.displayName)
        }
      }
    }

    public static func fetchDescriptor(
      with predicate: Predicate<SoundFontModel>? = nil
    ) -> FetchDescriptor<SoundFontModel> {
      .init(predicate: predicate, sortBy: [SortDescriptor(\.displayName)])
    }
  }
}

extension SchemaV1.SoundFontModel {

  public static func create(
    name: String,
    location: Location,
    fileInfo: SF2FileInfo,
    tags: [TagModel]
  ) throws -> SoundFontModel {
    @Dependency(\.modelContextProvider) var context
    @Dependency(\.uuid) var uuid

    let soundFontInfo = SoundFontInfoModel(
      originalName: name,
      embeddedName: String(fileInfo.embeddedName()),
      embeddedComment: String(fileInfo.embeddedComment()),
      embeddedAuthor: String(fileInfo.embeddedAuthor()),
      embeddedCopyright: String(fileInfo.embeddedCopyright())
    )

    context.insert(soundFontInfo)

    let soundFont = SoundFontModel(
      uuid: uuid(),
      name: name,
      location: location,
      info: soundFontInfo
    )

    context.insert(soundFont)

    let presets = (0..<fileInfo.size()).map { index in
      let presetInfo = fileInfo[index]
      let preset = PresetModel(
        soundFontPresetId: .init(soundFont: soundFont.uuid, preset: index),
        name: String(presetInfo.name()),
        bank: Int(presetInfo.bank()),
        program: Int(presetInfo.bank())
      )
      context.insert(preset)
      return preset
    }

    for tag in tags {
      tag.tag(soundFont: soundFont)
    }

    soundFont.tags = tags
    soundFont.presets = presets

    try context.save()

    return soundFont
  }

  public static func add(name: String, kind: SoundFontKind, tags: [TagModel]) throws -> SoundFontModel {
    let location = kind.asLocation
    var fileInfo = SF2FileInfo(location.path)
    guard fileInfo.load() else {
      throw ModelError.loadFailure(name: name)
    }

    return try create(name: name, location: location, fileInfo: fileInfo, tags: tags)
  }

  public static func add(resourceTag: SF2ResourceFileTag) throws -> SoundFontModel {
    var fileInfo = SF2FileInfo(resourceTag.url.path(percentEncoded: false))
    fileInfo.load()
    let kind: SoundFontKind = .builtin(resource: resourceTag.url)
    return try add(
      name: resourceTag.name,
      kind: kind,
      tags: [TagModel.ubiquitous(.all), TagModel.ubiquitous(.builtIn)]
    )
  }

  public static func addBuiltIn() throws -> [SoundFontModel] {
    try SF2ResourceFileTag.allCases.map { try add(resourceTag: $0) }
  }
}

extension SchemaV1.SoundFontModel {

  public static func with(tag: TagModel) throws -> [SoundFontModel] {
    let found = tag.orderedFonts
    if !found.isEmpty {
      return found
    }
    _ = try addBuiltIn()
    return tag.orderedFonts
  }
}

//  func soundFonts(with tagId: PersistentIdentifier) -> [SoundFont] {
//    let fetchDescriptor = SoundFont.fetchDescriptor(by: tagId)
//    return (try? fetch(fetchDescriptor)) ?? []
//  }
//
//  struct PickedStatus {
//    public let good: Int
//    public let bad: [String]
//
//    public init(good: Int, bad: [String]) {
//      self.good = good
//      self.bad = bad
//    }
//  }
//
//  func picked(urls: [URL]) -> PickedStatus {
//    var good = 0
//    var bad = [String]()
//
//    for url in urls {
//      let fileName = url.lastPathComponent
//      let displayName = String(fileName[fileName.startIndex..<(fileName.lastIndex(of: ".") ?? fileName.endIndex)])
//      let destination = FileManager.default.sharedPath(for: fileName)
//
//      do {
//        try FileManager.default.moveItem(at: url, to: destination)
//      } catch let err as NSError {
//        if err.code != NSFileWriteFileExistsError {
//          bad.append(fileName)
//          continue
//        }
//      }
//
//      do {
//        _ = try addSoundFont(name: displayName, kind: .installed(file: destination))
//      } catch SF2FileError.loadFailure {
//        bad.append(fileName)
//        continue
//      } catch {
//        bad.append(fileName)
//        continue
//      }
//
//      good += 1
//    }
//
//    for (index, path) in FileManager.default.sharedContents.enumerated() {
//      print(index, path)
//    }
//
//    return .init(good: good, bad: bad)
//  }
//}
//
//
//extension PersistenceReaderKey {
//  static public func soundFontKey(_ key: String) -> Self where Self == ModelIdentifierStorageKey<SoundFont.ID?> {
//    ModelIdentifierStorageKey(key)
//  }
//}
//
//extension PersistenceReaderKey where Self == ModelIdentifierStorageKey<SoundFont.ID?> {
//  static public var selectedSoundFont: Self { tagKey("selectedSoundFont") }
//}
