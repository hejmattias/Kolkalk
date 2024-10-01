
import SwiftUI
import Foundation

// FoodData-klassen som hanterar listan av livsmedel
class FoodData: ObservableObject {
    @Published var foodList: [FoodItem] = []

    init() {
        loadFromUserDefaults()
    }

    func addFoodItem(_ foodItem: FoodItem) {
        foodList.append(foodItem)
        saveToUserDefaults()
    }

    func saveToUserDefaults() {
        let userAddedFoods = foodList.filter { $0.isDefault != true }
        if let data = try? JSONEncoder().encode(userAddedFoods) {
            UserDefaults.standard.set(data, forKey: "userFoodList")
        }
    }

    func loadFromUserDefaults() {
        var updatedFoodList = defaultFoodList
        if let data = UserDefaults.standard.data(forKey: "userFoodList"),
           let savedUserFoods = try? JSONDecoder().decode([FoodItem].self, from: data) {
            updatedFoodList.append(contentsOf: savedUserFoods)
        }
        foodList = updatedFoodList
    }

    private var defaultFoodList: [FoodItem] {
        return [
            FoodItem(name: "Äpple", carbsPer100g: 11.4, grams: 0, gramsPerDl: 65, isDefault: true),
            FoodItem(name: "Fiskpinnar", carbsPer100g: 10, grams: 0,  gramsPerDl: 50, styckPerGram: 100, isDefault: true),
            FoodItem(name: "pinnfiskar", carbsPer100g: 10, grams: 0,  styckPerGram: 100, isDefault: true),
            FoodItem(name: "Banan", carbsPer100g: 22.8, grams: 0, gramsPerDl: 85, isDefault: true)
        ]
    }
}
