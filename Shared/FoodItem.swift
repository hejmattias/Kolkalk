// Shared/FoodItem.swift

import Foundation

struct FoodItem: Identifiable, Codable, Hashable, Equatable {
    var id: UUID
    var name: String
    var carbsPer100g: Double?
    var grams: Double
    var gramsPerDl: Double?
    var styckPerGram: Double?
    var inputUnit: String? // "g", "dl", "st"
    var isDefault: Bool?
    var hasBeenLogged: Bool = false
    var isFavorite: Bool = false // Ny egenskap för favoritmarkering

    // MARK: - Anpassad initialiserare för Codable

    enum CodingKeys: String, CodingKey {
        case id, name, carbsPer100g, grams, gramsPerDl, styckPerGram, inputUnit, isDefault, hasBeenLogged, isFavorite
    }

    init(
        id: UUID = UUID(),
        name: String,
        carbsPer100g: Double?,
        grams: Double,
        gramsPerDl: Double? = nil,
        styckPerGram: Double? = nil,
        inputUnit: String? = nil,
        isDefault: Bool? = nil,
        hasBeenLogged: Bool = false,
        isFavorite: Bool = false // Inkludera isFavorite i initialiseraren
    ) {
        self.id = id
        self.name = name
        self.carbsPer100g = carbsPer100g
        self.grams = grams
        self.gramsPerDl = gramsPerDl
        self.styckPerGram = styckPerGram
        self.inputUnit = inputUnit
        self.isDefault = isDefault
        self.hasBeenLogged = hasBeenLogged
        self.isFavorite = isFavorite
    }

    // Anpassad initialiserare för att hantera bakåtkompatibilitet
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        carbsPer100g = try container.decodeIfPresent(Double.self, forKey: .carbsPer100g)
        grams = try container.decode(Double.self, forKey: .grams)
        gramsPerDl = try container.decodeIfPresent(Double.self, forKey: .gramsPerDl)
        styckPerGram = try container.decodeIfPresent(Double.self, forKey: .styckPerGram)
        inputUnit = try container.decodeIfPresent(String.self, forKey: .inputUnit)
        isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault)
        hasBeenLogged = try container.decodeIfPresent(Bool.self, forKey: .hasBeenLogged) ?? false
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false // Dekodera isFavorite
    }

    // Funktion för att formatera detaljer (används i logToHealth)
    func formattedDetail() -> String {
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
                inputValue = grams
                unitString = "g"
            }
        case "st":
            if let styckPerGram = styckPerGram, styckPerGram > 0 {
                inputValue = grams / styckPerGram
                unitString = "st"
            } else {
                inputValue = grams
                unitString = "g"
            }
        default:
            inputValue = grams
            unitString = "g"
        }

        return "\(String(format: "%.1f", inputValue))\(unitString)"
    }

    // Beräknad egenskap för totala kolhydrater
    var totalCarbs: Double {
        return (carbsPer100g ?? 0) * grams / 100
    }
}

