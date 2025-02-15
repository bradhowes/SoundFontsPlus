// Copyright © 2024 Brad Howes. All rights reserved.

import ComposableArchitecture
import Dependencies
import Engine
import FileHash
import Foundation
import SF2ResourceFiles
import SwiftData
import Tagged

extension SchemaV1 {

  @Model
  public final class SoundFontModel {
    public typealias Key = Tagged<SoundFontModel, UUID>

    public var internalKey: UUID
    public var key: Key { .init(internalKey) }

    public var displayName: String
    public var location: Location

    @Relationship(deleteRule: .cascade, inverse: \PresetModel.owner)
    public var presets: [PresetModel]

    @Relationship(inverse: \TagModel.tagged)
    public var tags: [TagModel]

    public var info: SoundFontInfoModel

    public var orderedPresets: [PresetModel] { presets.sorted(by: { $0.key < $1.key }) }
    public var orderedVisiblePresets: [PresetModel] { presets.filter(\.visible).sorted(by: { $0.key < $1.key }) }

    public init(key: Key, name: String, location: Location, info: SoundFontInfoModel) {
      self.internalKey = key.rawValue
      self.displayName = name
      self.location = location
      self.presets = []
      self.tags = []
      self.info = info
    }

//    public func kind() throws -> SoundFontKind {
//      switch location.kind {
//      case .builtin:
//        guard let url = location.url else {
//          throw ModelError.invalidLocation(name: self.displayName)
//        }
//        return .builtin(resource: url)
//      case .installed:
//        guard let url = location.url else {
//          throw ModelError.invalidLocation(name: self.displayName)
//        }
//        return .installed(file: url)
//      case .external:
//        guard let data = location.raw else {
//          throw ModelError.invalidLocation(name: self.displayName)
//        }
//        do {
//          return .external(bookmark: try Bookmark.from(data: data))
//        } catch {
//          throw ModelError.invalidBookmark(name: self.displayName)
//        }
//      }
//    }
//
    public func tag(with tag: TagModel) {
      self.tags.append(tag)
      tag.tag(soundFont: self)
    }

    public static func fetchDescriptor(
      with predicate: Predicate<SoundFontModel>? = nil
    ) -> FetchDescriptor<SoundFontModel> {
      .init(predicate: predicate, sortBy: [SortDescriptor(\.displayName)])
    }
  }
}

extension SchemaV1.SoundFontModel {

  @discardableResult
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
      key: .init(uuid()),
      name: name,
      location: location,
      info: soundFontInfo
    )

    context.insert(soundFont)

    let presets = (0..<fileInfo.size()).map { index in
      let presetInfo = fileInfo[index]
      let preset = PresetModel(
        owner: soundFont,
        presetIndex: index,
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

  public static func add(name: String, location: Location, tags: [TagModel]) throws -> SoundFontModel {
    var fileInfo = SF2FileInfo(location.path)
    guard fileInfo.load() else {
      throw ModelError.loadFailure(name: name)
    }

    return try create(name: name, location: location, fileInfo: fileInfo, tags: tags)
  }

  public static func add(resourceTag: SF2ResourceFileTag) throws -> SoundFontModel {
    var fileInfo = SF2FileInfo(resourceTag.url.path(percentEncoded: false))
    fileInfo.load()
    return try add(
      name: resourceTag.name,
      location: .init(kind: .builtin, url: resourceTag.url, raw: nil),
      tags: [TagModel.ubiquitous(.all), TagModel.ubiquitous(.builtIn)]
    )
  }

  public static func addBuiltIn() throws -> [SoundFontModel] {
    try SF2ResourceFileTag.allCases.map { try add(resourceTag: $0) }
  }

  public static func delete(key: Key) throws {
    @Dependency(\.modelContextProvider) var context
    let fetchDescriptor = SoundFontModel.fetchDescriptor(with: #Predicate { $0.internalKey == key.rawValue })
    let found = try context.fetch(fetchDescriptor)
    if found.count == 1 {
      let font = found[0]
      if font.location.isInstalled,
         let url = font.location.url {
        try FileManager.default.removeItem(at: url)
      }
      context.delete(found[0])
      try context.save()
    }
  }

  public static func fetch(key: SoundFontModel.Key) throws -> SoundFontModel {
    @Dependency(\.modelContextProvider) var context
    let fetchDescriptor = SoundFontModel.fetchDescriptor(with: #Predicate{ $0.internalKey == key.rawValue })
    return try context.fetch(fetchDescriptor)[0]
  }

  public static func tagged(with key: TagModel.Key) throws -> [SoundFontModel] {
    let tagModel = try TagModel.fetchOptional(key: key) ?? TagModel.ubiquitous(.all)
    let found = tagModel.orderedFonts
    if !found.isEmpty {
      return found
    } else if tagModel.key == TagModel.Ubiquitous.all.key {
      _ = try addBuiltIn()
    }
    return tagModel.orderedFonts
  }
}

extension SoundFontModel: @unchecked Sendable {}
