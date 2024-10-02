import SwiftUI
import Foundation

// Plate-klassen som hanterar tallrikens innehåll
class Plate: ObservableObject {
    @Published var items: [FoodItem] = []

    // Lägg till ett livsmedel på tallriken
    func addItem(_ item: FoodItem) {
        if item.isDefault == true, let index = items.firstIndex(where: { $0.id == item.id }) {
            // Ersätt endast om det är ett standardlivsmedel
            items[index] = item
        } else {
            // Lägg till nya poster för användarskapade livsmedel
            items.append(item)
        }
        saveToUserDefaults()
    }

    // Töm tallriken
    func emptyPlate() {
        items.removeAll()
        saveToUserDefaults()
    }

    // Spara tallrikens innehåll till UserDefaults
    func saveToUserDefaults() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: "plateItems")
        }
    }

    // Ladda tallrikens innehåll från UserDefaults
    func loadFromUserDefaults() {
        if let data = UserDefaults.standard.data(forKey: "plateItems"),
           let savedItems = try? JSONDecoder().decode([FoodItem].self, from: data) {
            items = savedItems
        }
    }
}
