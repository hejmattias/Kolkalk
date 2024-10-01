import SwiftUI
import Foundation

struct FoodItem: Identifiable, Codable, Hashable {
    var id = UUID()  // Unik identifierare för varje livsmedel
    var name: String  // Livsmedelsnamn
    var carbsPer100g: Double?  // Kolhydrater per 100 gram
    var grams: Double  // Totala gram för det aktuella objektet på tallriken
    var gramsPerDl: Double?  // Gram per deciliter
    var styckPerGram: Double?  // Gram per styck
    var isDefault: Bool? = false  // För att hantera standardvärden
    var inputUnit: String?  // Lagrar enheten som användes vid tillägg

    // Beräknar den totala mängden kolhydrater baserat på gram och kolhydrater per 100 gram
    var totalCarbs: Double {
        if let carbsPer100g = carbsPer100g {
            return (carbsPer100g / 100) * grams
        } else {
            return 0.0
        }
    }

    // Metod för att formatera detaljerna om livsmedlet, beroende på vilken enhet som används
    func formattedDetail() -> String {
        let gramsString = "\(String(format: "%.1f", grams))g"

        guard let inputUnit = inputUnit else {
            return gramsString
        }

        let inputValue: Double
        let unitString: String

        switch inputUnit {
        case "g":
            inputValue = grams
            unitString = "g"
        case "dl":
            if let gramsPerDl = gramsPerDl, gramsPerDl > 0 {
                inputValue = grams / gramsPerDl
                unitString = "dl"
            } else {
                return gramsString
            }
        case "st":
            if let styckPerGram = styckPerGram, styckPerGram > 0 {
                inputValue = grams / styckPerGram
                unitString = "st"
            } else {
                return gramsString
            }
        default:
            return gramsString
        }

        return "\(String(format: "%.1f", inputValue))\(unitString) (\(gramsString))"
    }
}
