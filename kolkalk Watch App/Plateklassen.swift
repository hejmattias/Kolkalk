
import SwiftUI
import Foundation

// Plate-klassen som hanterar tallrikens innehåll
class Plate: ObservableObject {
    @Published var items: [FoodItem] = []

    func addItem(_ item: FoodItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
        saveToUserDefaults()
    }

    func emptyPlate() {
        items.removeAll()
        saveToUserDefaults()
    }

    func saveToUserDefaults() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: "plateItems")
        }
    }

    func loadFromUserDefaults() {
        if let data = UserDefaults.standard.data(forKey: "plateItems"),
           let savedItems = try? JSONDecoder().decode([FoodItem].self, from: data) {
            items = savedItems
        }
    }
}
