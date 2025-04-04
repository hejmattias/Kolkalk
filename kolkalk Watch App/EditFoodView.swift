// Kolkalk.zip/kolkalk Watch App/EditFoodView.swift
import SwiftUI
import Foundation

struct EditFoodView: View {
    @ObservedObject var plate: Plate
    @State private var currentInputString: String
    // --- initialUnit är kvar för att skicka till NumpadView ---
    @State private var initialUnit: String = "g"
    // ---
    var item: FoodItem
    @Environment(\.dismiss) var dismiss

    init(plate: Plate, item: FoodItem) {
        self._plate = ObservedObject(initialValue: plate)
        self.item = item

        // Beräkna initialt värde och enhet
        let value: Double
        let unit: String
        switch item.inputUnit {
            case "dl":
                if let gPerDl = item.gramsPerDl, gPerDl > 0 {
                    value = item.grams / gPerDl; unit = "dl"
                } else { value = item.grams; unit = "g" }
            case "st":
                if let sPerG = item.styckPerGram, sPerG > 0 {
                    value = item.grams / sPerG; unit = "st"
                } else { value = item.grams; unit = "g" }
            default:
                value = item.grams; unit = "g"
        }

        // --- ÄNDRING HÄR: Använd %.2f vid initiering ---
        self._currentInputString = State(initialValue: String(format: "%.2f", value).replacingOccurrences(of: ".", with: ","))
        // ---
        self._initialUnit = State(initialValue: unit)
    }


    var body: some View {
        NumpadView(
            valueString: $currentInputString,
            title: "Redigera \(item.name)",
            mode: .foodItem,
            foodName: item.name,
            carbsPer100g: item.carbsPer100g,
            gramsPerDl: item.gramsPerDl,
            styckPerGram: item.styckPerGram,
            initialUnit: initialUnit, // <-- Skicka med den initiala enheten
            onConfirmFoodItem: { value, unit in
                var updatedItem = item
                switch unit {
                case "g": updatedItem.grams = value
                case "dl":
                    if let gPerDl = item.gramsPerDl, gPerDl > 0 { updatedItem.grams = value * gPerDl }
                    else { updatedItem.grams = 0 }
                case "st":
                    if let sPerG = item.styckPerGram, sPerG > 0 { updatedItem.grams = value * sPerG }
                    else { updatedItem.grams = 0 }
                default: updatedItem.grams = value
                }
                updatedItem.inputUnit = unit
                updatedItem.hasBeenLogged = false
                plate.updateItem(updatedItem)
                dismiss()
            }
        )
    }
}
