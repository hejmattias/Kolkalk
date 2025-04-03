// Kolkalk.zip/kolkalk Watch App/EditFoodView.swift
import SwiftUI

struct EditFoodView: View {
    @ObservedObject var plate: Plate
    // <<< CHANGE START >>>
    // Ta bort @State private var selectedGrams: Int
    @State private var currentInputString: String // Ny state för bindning
    // <<< CHANGE END >>>
    var item: FoodItem
    @Environment(\.dismiss) var dismiss

    init(plate: Plate, item: FoodItem) {
        self._plate = ObservedObject(initialValue: plate)
        self.item = item
        // <<< CHANGE START >>>
        // Initiera strängen baserat på itemets nuvarande värde och enhet
        let initialValue: Double
        let initialUnit: String
        switch item.inputUnit {
            case "dl":
                if let gPerDl = item.gramsPerDl, gPerDl > 0 {
                    initialValue = item.grams / gPerDl
                    initialUnit = "dl"
                } else {
                    initialValue = item.grams; initialUnit = "g" // Fallback till gram
                }
            case "st":
                if let sPerG = item.styckPerGram, sPerG > 0 {
                    initialValue = item.grams / sPerG
                    initialUnit = "st"
                } else {
                    initialValue = item.grams; initialUnit = "g" // Fallback till gram
                }
            default: // "g" eller nil
                initialValue = item.grams
                initialUnit = "g"
        }
         // Formattera Double till String med kommatecken och lägg till enhet
         self._currentInputString = State(initialValue: String(format: "%.1f", initialValue).replacingOccurrences(of: ".", with: ",")) // Ta bort + initialUnit här, hanteras i NumpadView
        // <<< CHANGE END >>>
    }


    var body: some View {
        // <<< CHANGE START >>>
        // Anropa den nya NumpadView
        NumpadView(
            valueString: $currentInputString, // Bind till den nya state-variabeln
            title: "Redigera \(item.name)", // Sätt en titel
            mode: .foodItem, // Sätt läget till foodItem
            foodName: item.name,
            carbsPer100g: item.carbsPer100g,
            gramsPerDl: item.gramsPerDl,
            styckPerGram: item.styckPerGram,
            onConfirmFoodItem: { value, unit in // Använd den specifika closuren
                var updatedItem = item

                // Uppdatera gram baserat på enhet (som tidigare)
                switch unit {
                case "g":
                    updatedItem.grams = value
                case "dl":
                    if let gramsPerDl = item.gramsPerDl, gramsPerDl > 0 {
                        updatedItem.grams = value * gramsPerDl
                    } else { updatedItem.grams = 0 } // Fallback
                case "st":
                    if let styckPerGram = item.styckPerGram, styckPerGram > 0 {
                        updatedItem.grams = value * styckPerGram
                    } else { updatedItem.grams = 0 } // Fallback
                default:
                     updatedItem.grams = value // Fallback, antar gram
                }

                updatedItem.inputUnit = unit
                updatedItem.hasBeenLogged = false // Markera som ologgad vid ändring

                plate.updateItem(updatedItem)

                dismiss() // Stäng vyn
            }
        )
        // <<< CHANGE END >>>
    }
}
