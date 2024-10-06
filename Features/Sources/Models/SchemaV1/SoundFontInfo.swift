// Copyright © 2024 Brad Howes. All rights reserved.

import Foundation
import SwiftData

extension SchemaV1 {
  
  @Model
  public final class SoundFontInfoModel {
    public var originalName: String
    public var embeddedName: String
    public var embeddedComment: String
    public var embeddedAuthor: String
    public var embeddedCopyright: String

    public init(
      originalName: String,
      embeddedName: String,
      embeddedComment: String,
      embeddedAuthor: String,
      embeddedCopyright: String
    ) {
      self.originalName = originalName
      self.embeddedName = embeddedName
      self.embeddedComment = embeddedComment
      self.embeddedAuthor = embeddedAuthor
      self.embeddedCopyright = embeddedCopyright
    }
  }
}
