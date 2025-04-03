// Kolkalk.zip/kolkalk Watch App/FoodDetailView.swift
import SwiftUI
import Foundation

struct FoodDetailView: View {
    @ObservedObject var plate: Plate
    var food: FoodItem
    @Binding var navigationPath: NavigationPath
    // <<< CHANGE START >>>
    // Ta bort @State private var selectedGrams: Int = 0, behövs inte längre här
    // <<< CHANGE END >>>
    var shouldEmptyPlate: Bool

    // <<< CHANGE START >>>
    // State för att hålla värdet som ska bindas till NumpadView
    @State private var currentInputString: String = "0"
    // <<< CHANGE END >>>

    var body: some View {
        // <<< CHANGE START >>>
        // Anropa den nya NumpadView
        NumpadView(
            valueString: $currentInputString, // Bind till den nya state-variabeln
            title: (shouldEmptyPlate ? "-+ " : "") + food.name, // Behåll titeln som den var
            mode: .foodItem, // Sätt läget till foodItem
            foodName: food.name, // Skicka med foodName (används inte för titel, men kan vara bra att ha)
            carbsPer100g: food.carbsPer100g,
            gramsPerDl: food.gramsPerDl,
            styckPerGram: food.styckPerGram,
            onConfirmFoodItem: { value, unit in // Använd den specifika closuren
                if shouldEmptyPlate {
                    plate.emptyPlate()
                }

                var newFood = food
                newFood.id = UUID() // Skapa nytt id

                // Uppdatera gram baserat på enhet (som tidigare)
                switch unit {
                case "g":
                    newFood.grams = value
                case "dl":
                    if let gramsPerDl = food.gramsPerDl, gramsPerDl > 0 {
                        newFood.grams = value * gramsPerDl
                    } else { newFood.grams = 0 } // Fallback
                case "st":
                    if let styckPerGram = food.styckPerGram, styckPerGram > 0 {
                        newFood.grams = value * styckPerGram
                    } else { newFood.grams = 0 } // Fallback
                default:
                    newFood.grams = value // Fallback om enhet är okänd, antar gram
                }

                newFood.inputUnit = unit
                plate.addItem(newFood)

                navigationPath = NavigationPath([Route.plateView]) // Gå till tallriken
            }
        )
        .onAppear {
            // Sätt ett initialvärde om det behövs, t.ex. "0"
            currentInputString = "0"
        }
        // <<< CHANGE END >>>
    }
}
