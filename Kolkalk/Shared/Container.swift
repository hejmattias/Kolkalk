// Shared/Container.swift

import Foundation
import UIKit

struct Container: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var weight: Double
    var imageData: Data? // Lägg till denna rad

    init(id: UUID = UUID(), name: String, weight: Double, imageData: Data? = nil) {
        self.id = id
        self.name = name
        self.weight = weight
        self.imageData = imageData
    }
}
