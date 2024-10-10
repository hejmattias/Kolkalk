import SwiftUI
import Foundation
import WidgetKit

class Plate: ObservableObject {
    @Published var items: [FoodItem] = []

    // Plate Singleton
    static let shared: Plate = {
        let instance = Plate()
        instance.loadFromUserDefaults()
        return instance
    }()

    var totalCarbs: Double {
        items.reduce(0) { $0 + $1.totalCarbs }
    }

    // Lägg till ett livsmedel på tallriken
    func addItem(_ item: FoodItem) {
        items.append(item)
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
        let appGroupID = "group.mg.kolkalk" // Ersätt med ditt faktiska App Group ID
        if let data = try? JSONEncoder().encode(items) {
            if let userDefaults = UserDefaults(suiteName: appGroupID) {
                userDefaults.set(data, forKey: "plateItems")
                // Spara totala kolhydrater separat
                let totalCarbsValue = items.reduce(0) { $0 + $1.totalCarbs }
                userDefaults.set(totalCarbsValue, forKey: "totalCarbs")
                print("Data har sparats till UserDefaults i WatchKit Extension med App Group ID: \(appGroupID)")
            } else {
                print("Kunde inte få åtkomst till UserDefaults med App Group ID: \(appGroupID) i WatchKit Extension")
            }
        } else {
            print("Misslyckades att koda items i WatchKit Extension")
        }

        // Notifiera WidgetKit att uppdatera komplikationen
        WidgetCenter.shared.reloadAllTimelines()
    }

    // Ladda tallrikens innehåll från UserDefaults
    func loadFromUserDefaults() {
        let appGroupID = "group.mg.kolkalk" // Ersätt med ditt faktiska App Group ID
        if let userDefaults = UserDefaults(suiteName: appGroupID),
           let data = userDefaults.data(forKey: "plateItems"),
           let savedItems = try? JSONDecoder().decode([FoodItem].self, from: data) {
            items = savedItems
        }
    }
}
