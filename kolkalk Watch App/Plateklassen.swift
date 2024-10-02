import SwiftUI
import Foundation

class Plate: ObservableObject {
    @Published var items: [FoodItem] = []

    // Lägg till ett livsmedel på tallriken
    func addItem(_ item: FoodItem) {
        items.append(item) // Lägg till varje livsmedel som en separat post
        saveToUserDefaults()
    }

    // Uppdatera ett befintligt livsmedel på tallriken
    func updateItem(_ updatedItem: FoodItem) {
        if let index = items.firstIndex(where: { $0.id == updatedItem.id }) {
            items[index] = updatedItem
            saveToUserDefaults()
        }
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
