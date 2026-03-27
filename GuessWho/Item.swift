//
//  Item.swift
//  GuessWho
//
//  Created by Charlie Kim on 3/23/26.
//

import Foundation

struct Item: Identifiable {
    let id = UUID()
    var timestamp: Date

    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
