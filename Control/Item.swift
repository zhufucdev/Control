//
//  Item.swift
//  Control
//
//  Created by Steve Reed on 2026/1/16.
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
