import AVFoundation
import Dependencies
import SharingGRDB
import SF2ResourceFiles
import Tagged

@Table
public struct Preset: Hashable, Identifiable {
  public typealias ID = Tagged<Self, Int64>

  public let id: ID
  public let index: Int
  public let bank: Int
  public let program: Int
  public let originalName: String
  public let soundFontId: SoundFont.ID

  public var displayName: String
  public var visible: Bool
  public var notes: String
}

@Table
public struct Favorite: Hashable, Identifiable {
  public typealias ID = Tagged<Self, Int64>

  public let id: ID
  public var displayName: String
  public var notes: String
  public var presetId: Preset.ID
}

@Table
public struct AudioConfig: Hashable, Identifiable {
  public typealias ID = Tagged<Self, Int64>

  public let id: ID
  public var gain: AUValue
  public var pan: AUValue
  public var keyboardLowestNoteEnabled: Bool

  public var keyboardLowestNote: Int?
  public var pitchBendRange: Int?
  public var presetTuning: AUValue?
  public var presetTranspose: Int?

  public let favoriteId: Favorite.ID?
  public let presetId: Preset.ID?
}

@Table
public struct DelayConfig: Hashable, Identifiable {
  public typealias ID = Tagged<Self, Int64>

  public let id: ID
  public var time: AUValue
  public var feedback: AUValue
  public var cutoff: AUValue
  public var wetDryMix: AUValue
  public var enabled: Bool
  public let audioConfigId: AudioConfig.ID
}

@Table
public struct ReverbConfig: Hashable, Identifiable {
  public typealias ID = Tagged<Self, Int64>

  public let id: ID
  public var preset: Int
  public var wetDryMix: AUValue
  public var enabled: Bool
  public let audioConfigId: AudioConfig.ID
}

@Table
public struct Tag: Hashable, Identifiable {
  public typealias ID = Tagged<Self, Int64>

  public enum Ubiquitous: CaseIterable {
    case all
    case builtIn
    case added
    case external

    public var name: String {
      switch self {
      case .all: return "All"
      case .builtIn: return "Built-in"
      case .added: return "Added"
      case .external: return "External"
      }
    }

    public var id: ID {
      switch self {
      case .all: return .init(1)
      case .builtIn: return .init(2)
      case .added: return .init(3)
      case .external: return .init(4)
      }
    }

    public static func isUbiquitous(id: ID) -> Bool {
      guard let last = Self.allCases.last else { fatalError() }
      return id <= last.id
    }

    public static func isUserDefined(id: ID) -> Bool { !isUbiquitous(id: id) }
  }

  public let id: ID
  public var name: String
  public var ordering: Int

  public var isUbiquitous: Bool { id.isUbiquitous }
  public var isUserDefined: Bool { id.isUserDefined }

  public func willDelete(_ db: Database) throws {
    if isUbiquitous {
      throw ModelError.deleteUbiquitous(name: self.name)
    }
  }

  static func from(ubi: (Int, Ubiquitous)) throws -> InsertOf<Tag> {
    return Tag.insert(
      Tag.Draft(
        name: ubi.1.name,
        ordering: ubi.0
      )
    )
  }
}

extension Tag.ID {

  public var isUbiquitous: Bool {
    guard let last = Tag.Ubiquitous.allCases.last else { fatalError() }
    return self <= last.id
  }

  public var isUserDefined: Bool { !self.isUbiquitous }
}

@Table
public struct TaggedSoundFont: Hashable {
  public let soundFontId: SoundFont.ID
  public let tagId: Tag.ID
}

