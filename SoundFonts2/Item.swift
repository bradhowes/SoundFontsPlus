//
//  Item.swift
//  SoundFonts2
//
//  Created by Brad Howes on 04/02/2024.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
