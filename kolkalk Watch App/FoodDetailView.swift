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

                var newFood = food
                newFood.id = UUID()  // Skapa ett nytt unikt id för varje ny instans

                // Uppdatera mängden beroende på enheten
                switch unit {
                case "g":
                    newFood.grams = value
                case "dl":
                    if let gramsPerDl = food.gramsPerDl, gramsPerDl > 0 {
                        newFood.grams = value * gramsPerDl
                    }
                case "st":
                    if let styckPerGram = food.styckPerGram, styckPerGram > 0 {
                        newFood.grams = value * styckPerGram
                    }
                default:
                    break
                }

                newFood.inputUnit = unit
                plate.addItem(newFood)  // Lägg till den nya posten på tallriken

                navigationPath = NavigationPath([Route.plateView])  // Gå tillbaka till tallriken
            }
           // .navigationBarBackButtonHidden(true)
        }
    }
}
