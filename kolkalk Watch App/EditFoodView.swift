import SwiftUI

struct EditFoodView: View {
    @ObservedObject var plate: Plate
    @State private var selectedGrams: Int
    var item: FoodItem
    @Environment(\.dismiss) var dismiss

    init(plate: Plate, item: FoodItem) {
        self._plate = ObservedObject(initialValue: plate)
        self.item = item
        self._selectedGrams = State(initialValue: Int(item.grams))
    }

    var body: some View {
        NumpadView(
            value: $selectedGrams,
            foodName: item.name,
            carbsPer100g: item.carbsPer100g ?? 0.0,
            gramsPerDl: item.gramsPerDl,
            styckPerGram: item.styckPerGram
        ) { value, unit in
            var updatedItem = item

            switch unit {
            case "g":
                updatedItem.grams = value
            case "dl":
                if let gramsPerDl = item.gramsPerDl, gramsPerDl > 0 {
                    updatedItem.grams = value * gramsPerDl
                }
            case "st":
                if let styckPerGram = item.styckPerGram, styckPerGram > 0 {
                    updatedItem.grams = value * styckPerGram
                }
            default:
                break
            }

            updatedItem.inputUnit = unit  // Uppdatera enheten

            plate.updateItem(updatedItem)  // Uppdatera den specifika posten på tallriken

            dismiss()  // Stäng vyn när ändringarna är sparade
        }
       // .navigationBarBackButtonHidden(true)
    }
}
