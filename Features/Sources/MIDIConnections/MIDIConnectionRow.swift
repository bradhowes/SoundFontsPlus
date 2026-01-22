// Copyright © 2025 Brad Howes. All rights reserved.

import CoreMIDI
import Models
import Sharing

public struct MIDIConnectionRow {
  public static var unknownChannel: UInt8 { 255 }
  public static var disabledFixedVolume: Int { MIDIConfig.disabledFixedVolume }

  public let id: MIDIUniqueID
  public let displayName: String
  public var channel: UInt8
  public var fixedVolume: Int
  public var autoConnect: Bool
  public var connected: Bool

  public init(
    id: MIDIUniqueID,
    displayName: String,
    channel: UInt8 = Self.unknownChannel,
    fixedVolume: Int = Self.disabledFixedVolume,
    autoConnect: Bool = false,
    connected: Bool = false,
  ) {
    self.id = id
    self.displayName = displayName
    self.channel = channel
    self.fixedVolume = fixedVolume
    self.autoConnect = autoConnect
    self.connected = connected
    if let config = MIDIConfig.with(id: id) {
      self.fixedVolume = config.fixedVolume
      self.autoConnect = config.autoConnect
    }
  }

  public func save() {
    withDatabaseWriter { db in
      try MIDIConfig.upsert {
        .init(
          uniqueId: self.id,
          autoConnect: self.autoConnect,
          fixedVolume: self.fixedVolume
        )
      }.execute(db)
    }
  }
}

extension MIDIConnectionRow: Equatable, Identifiable {}
