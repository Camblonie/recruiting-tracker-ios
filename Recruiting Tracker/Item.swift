//
//  Item.swift
//  Recruiting Tracker
//
//  Created by Scott Campbell on 5/1/25.
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
