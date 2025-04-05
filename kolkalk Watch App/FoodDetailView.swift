// Kolkalk/kolkalk Watch App/FoodDetailView.swift
import SwiftUI
import Foundation

struct FoodDetailView: View {
    @ObservedObject var plate: Plate
    var food: FoodItem
    @Binding var navigationPath: NavigationPath
    var shouldEmptyPlate: Bool

    @State private var currentInputString: String = "0"

    var body: some View {
        NumpadView(
            valueString: $currentInputString,
            title: (shouldEmptyPlate ? "-+ " : "") + food.name,
            mode: .foodItem,
            foodName: food.name,
            carbsPer100g: food.carbsPer100g,
            gramsPerDl: food.gramsPerDl,
            styckPerGram: food.styckPerGram,
            onConfirmFoodItem: { value, unit in
                // Uppdatera plate-modellen
                if shouldEmptyPlate {
                    plate.emptyPlate()
                }
                var newFood = food
                newFood.id = UUID()
                switch unit {
                case "g": newFood.grams = value
                case "dl":
                    if let gramsPerDl = food.gramsPerDl, gramsPerDl > 0 { newFood.grams = value * gramsPerDl }
                    else { newFood.grams = 0 }
                case "st":
                    if let styckPerGram = food.styckPerGram, styckPerGram > 0 { newFood.grams = value * styckPerGram }
                    else { newFood.grams = 0 }
                default: newFood.grams = value
                }
                newFood.inputUnit = unit
                plate.addItem(newFood)
            },
            // <<< ÄNDRING: Logik för att manuellt poppa och pusha >>>
            onDismissAndNavigate: {
                // Denna kod körs EFTER att NumpadView (.sheet) har stängts (med liten fördröjning från NumpadView)

                // Kontrollera om stacken har minst de två vyer vi förväntar oss
                // (FoodListView följt av FoodDetailView)
                if navigationPath.count >= 2 {
                    print("NavPath count before pop: \(navigationPath.count)")
                    // Ta bort de två sista (FoodDetailView och FoodListView)
                    navigationPath.removeLast(2)
                    print("NavPath count after pop: \(navigationPath.count)")
                    // Lägg till PlateView
                    navigationPath.append(Route.plateView)
                    print("NavPath count after append: \(navigationPath.count)")
                } else {
                    // Fallback: Om stacken är oväntat kort, ersätt den helt
                    print("NavPath count was < 2, resetting to PlateView.")
                    navigationPath = NavigationPath([Route.plateView])
                }
            }
            // <<< SLUT ÄNDRING >>>
        )
        .onAppear {
            currentInputString = "0"
        }
    }
}
