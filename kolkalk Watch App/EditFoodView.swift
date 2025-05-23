// Kolkalk.zip/kolkalk Watch App/EditFoodView.swift
import SwiftUI
import Foundation

// MARK: - String Extension for Formatting
extension String {
    func formatForInitialDisplay() -> String {
        let cleanedString = self.replacingOccurrences(of: ",", with: ".")
        guard let doubleValue = Double(cleanedString) else {
            return self // Return original if not a valid double
        }

        if floor(doubleValue) == doubleValue { // Integer
            return String(format: "%.0f", doubleValue)
        } else {
            // Try with one decimal place
            let oneDecimalFormatted = String(format: "%.1f", doubleValue)
            // Convert back to double to check if precision was lost (e.g. 12.55 vs 12.5)
            if let oneDecimalDouble = Double(oneDecimalFormatted.replacingOccurrences(of: ",", with: ".")), oneDecimalDouble == doubleValue {
                return oneDecimalFormatted.replacingOccurrences(of: ".", with: ",")
            }
            // Default to two decimal places if more precision is needed (e.g. 12.55)
            // Or if the number naturally has two decimal places (e.g. from a %.2f format initially)
            var twoDecimalFormatted = String(format: "%.2f", doubleValue).replacingOccurrences(of: ".", with: ",")
            // Remove trailing ",0" if it became something like "12,50" and should be "12,5"
            // This is handled by the oneDecimalFormatted check now.
            // However, ensure that "12,00" is not returned from here if floor(doubleValue) == doubleValue was missed.
            if twoDecimalFormatted.hasSuffix(",00") { // Should be caught by floor check, but as a safeguard
                 return String(format: "%.0f", doubleValue)
            }
            // If it became "XX,Y0", trim to "XX,Y"
            if twoDecimalFormatted.hasSuffix("0") && twoDecimalFormatted.contains(",") {
                let parts = twoDecimalFormatted.split(separator: ",")
                if parts.count == 2 && parts[1].count == 2 && parts[1].hasSuffix("0") {
                     twoDecimalFormatted = String(parts[0]) + "," + String(parts[1].dropLast())
                }
            }
            return twoDecimalFormatted
        }
    }
}

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

        // --- ÄNDRING HÄR: Använd formatForInitialDisplay ---
        let initialStringRepresentation = String(value) // Konvertera Double till String
        self._currentInputString = State(initialValue: initialStringRepresentation.formatForInitialDisplay())
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
