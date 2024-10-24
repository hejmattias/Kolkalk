//
//  Container.swift
//  Kolkalk
//
//  Created by Mattias Göransson on 2024-10-24.
//


// Shared/Container.swift

import Foundation

struct Container: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var weight: Double

    init(id: UUID = UUID(), name: String, weight: Double) {
        self.id = id
        self.name = name
        self.weight = weight
    }
}
