// Copyright © 2024 Brad Howes. All rights reserved.

import Foundation
import SwiftData

extension SchemaV1 {
  
  @Model
  public final class PresetInfoModel {
    public var originalName: String
    public var notes: String?

    public init(originalName: String) {
      self.originalName = originalName
    }
  }
}

//extension ModelContext {
//
//  func createPresetInfo(originalName: String, bank: Int, program: Int) throws -> PresetInfo {
//    let entity = PresetInfo(originalName: originalName, bank: bank, program: program)
//    self.insert(entity)
//    try self.save()
//    return entity
//  }
//
//  func presetInfos(_ fetchDescriptor: FetchDescriptor<PresetInfo>? = nil) throws -> [PresetInfo] {
//    return try self.fetch(fetchDescriptor ?? FetchDescriptor<PresetInfo>())
//  }
//}
//
//extension SchemaV1.PresetInfo : Identifiable {
//  public var id: PersistentIdentifier { persistentModelID }
//}
