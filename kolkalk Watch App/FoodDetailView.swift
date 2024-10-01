import SwiftUI
import Foundation

struct FoodDetailView: View {
    @ObservedObject var plate: Plate
    var food: FoodItem
    @Binding var navigationPath: NavigationPath
    @State private var selectedGrams: Int = 0
    var shouldEmptyPlate: Bool

    var body: some View {
        VStack {
            NumpadView(
                value: $selectedGrams,
                foodName: (shouldEmptyPlate ? "-+ " : "") + food.name,
                carbsPer100g: food.carbsPer100g ?? 0.0,
                gramsPerDl: food.gramsPerDl,
                styckPerGram: food.styckPerGram
            ) { value, unit in
                if shouldEmptyPlate {
                    plate.emptyPlate()
                }

                var selectedFood = food

                switch unit {
                case "g":
                    selectedFood.grams = value
                case "dl":
                    if let gramsPerDl = food.gramsPerDl, gramsPerDl > 0 {
                        selectedFood.grams = value * gramsPerDl
                    }
                case "st":
                    if let styckPerGram = food.styckPerGram, styckPerGram > 0 {
                        selectedFood.grams = value * styckPerGram
                    }
                default:
                    break
                }

                selectedFood.inputUnit = unit  // Lagra enheten som användes

                plate.addItem(selectedFood)

                navigationPath = NavigationPath([Route.plateView])
            }
            .navigationBarBackButtonHidden(true)
        }
    }
}
