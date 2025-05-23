// Kolkalk/IOSAddEditFoodItemView.swift

import SwiftUI

struct IOSAddEditFoodItemView: View {
    @ObservedObject var foodData: FoodData_iOS
    var foodToEdit: FoodItem?

    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var carbsPer100gString: String = ""
    @State private var gramsPerDlString: String = ""
    @State private var styckPerGramString: String = ""
    @State private var isFavorite: Bool = false
    @State private var errorMessage: String? = nil

    var isEditing: Bool { foodToEdit != nil }

    var body: some View {
        Form {
            Section(header: Text("Detaljer")) {
                TextField("Namn", text: $name)
                HStack {
                     TextField("Kolhydrater (gk per 100g)", text: $carbsPer100gString)
                         .keyboardType(.decimalPad)
                         // *** UPPDATERAD onChange SYNTAX ***
                         .onChange(of: carbsPer100gString) { oldValue, newValue in //
                             let filtered = newValue.replacingOccurrences(of: ",", with: ".") //
                             if filtered.filter({ $0 == "." }).count <= 1 { //
                                 // Undvik oändlig loop genom att bara uppdatera om värdet faktiskt ändrats
                                 if carbsPer100gString != filtered { //
                                     carbsPer100gString = filtered //
                                 }
                             } else if !newValue.isEmpty { //
                                 // Återställ till gamla värdet om fler än en punkt matades in
                                 carbsPer100gString = oldValue //
                             }
                         }
                     Text("gk/100g").foregroundColor(.gray) //
                 }
                 HStack {
                     TextField("Vikt per dl (valfritt)", text: $gramsPerDlString) //
                         .keyboardType(.decimalPad) //
                         // *** UPPDATERAD onChange SYNTAX ***
                         .onChange(of: gramsPerDlString) { oldValue, newValue in //
                             let filtered = newValue.replacingOccurrences(of: ",", with: ".") //
                             if filtered.filter({ $0 == "." }).count <= 1 { //
                                 if gramsPerDlString != filtered { //
                                     gramsPerDlString = filtered //
                                 }
                             } else if !newValue.isEmpty { //
                                 gramsPerDlString = oldValue //
                             }
                         }
                     Text("g/dl").foregroundColor(.gray) //
                 }
                 HStack {
                     TextField("Vikt per styck (valfritt)", text: $styckPerGramString) //
                         .keyboardType(.decimalPad) //
                         // *** UPPDATERAD onChange SYNTAX ***
                         .onChange(of: styckPerGramString) { oldValue, newValue in //
                             let filtered = newValue.replacingOccurrences(of: ",", with: ".") //
                             if filtered.filter({ $0 == "." }).count <= 1 { //
                                 if styckPerGramString != filtered { //
                                     styckPerGramString = filtered //
                                 }
                             } else if !newValue.isEmpty { //
                                 styckPerGramString = oldValue //
                             }
                         }
                     Text("g/st").foregroundColor(.gray) //
                 }
                Toggle("Favorit", isOn: $isFavorite) //
            }

            // Felmeddelandesektion
            if let message = errorMessage { //
                 Section { //
                     Text(message) //
                         .foregroundColor(.red) //
                 }
             }
        }
        .navigationTitle(isEditing ? "Redigera livsmedel" : "Lägg till livsmedel") //
        .navigationBarItems( //
             leading: Button("Avbryt") { dismiss() }, //
             trailing: Button("Spara") { saveFoodItem() } //
                         .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || !isValidDouble(carbsPer100gString)) //
         )
        .onAppear { //
            print("DEBUG: IOSAddEditFoodItemView .onAppear - foodToEdit is: \(foodToEdit?.name ?? "nil")") //
            if let food = foodToEdit { //
                name = food.name //
                carbsPer100gString = String(food.carbsPer100g ?? 0).replacingOccurrences(of: ".", with: ",") //
                gramsPerDlString = food.gramsPerDl != nil ? String(food.gramsPerDl!).replacingOccurrences(of: ".", with: ",") : "" //
                styckPerGramString = food.styckPerGram != nil ? String(food.styckPerGram!).replacingOccurrences(of: ".", with: ",") : "" //
                isFavorite = food.isFavorite //
            } else {
                name = "" //
                carbsPer100gString = "" //
                gramsPerDlString = "" //
                styckPerGramString = "" //
                isFavorite = false //
            }
            errorMessage = nil //
        }
    }

    // Hjälpfunktion för Spara-knappens validering
    private func isValidDouble(_ string: String) -> Bool { //
        return Double(string.replacingOccurrences(of: ",", with: ".")) != nil //
    }

    // saveFoodItem() är oförändrad
    func saveFoodItem() {
        let sanitizedName = name.trimmingCharacters(in: .whitespacesAndNewlines) //
        // ***** ÄNDRING START *****
        // Säkerställ att punkt används som decimaltecken innan konvertering till Double
        let sanitizedCarbs = carbsPer100gString.replacingOccurrences(of: ",", with: ".") //
        let sanitizedGramsDl = gramsPerDlString.replacingOccurrences(of: ",", with: ".") //
        let sanitizedStyckGram = styckPerGramString.replacingOccurrences(of: ",", with: ".") //
        // ***** ÄNDRING SLUT *****

        guard !sanitizedName.isEmpty else { //
            errorMessage = "Namn får inte vara tomt." //
            return
        }
        // Validera direkt med den punkt-formaterade strängen
        guard let carbsPer100g = Double(sanitizedCarbs), carbsPer100g >= 0 else { //
            errorMessage = "Ange ett giltigt, icke-negativt värde för kolhydrater." //
            // Återställ fältet om det är ogiltigt? Eller låt användaren korrigera.
            // self.carbsPer100gString = "" // Alternativ
            return
        }

        let gramsPerDl: Double? //
        if !sanitizedGramsDl.isEmpty { //
            guard let value = Double(sanitizedGramsDl), value >= 0 else { //
                errorMessage = "Ange ett giltigt, icke-negativt värde för vikt per dl." //
                return
            }
            gramsPerDl = value //
        } else {
            gramsPerDl = nil //
        }

        let styckPerGram: Double? //
        if !sanitizedStyckGram.isEmpty { //
             guard let value = Double(sanitizedStyckGram), value >= 0 else { //
                 errorMessage = "Ange ett giltigt, icke-negativt värde för vikt per styck." //
                 return
             }
             styckPerGram = value //
         } else {
             styckPerGram = nil //
         }

        errorMessage = nil //

        let foodItemToSave = FoodItem( //
            id: foodToEdit?.id ?? UUID(), //
            name: sanitizedName, //
            carbsPer100g: carbsPer100g, //
            grams: 0, //
            gramsPerDl: gramsPerDl, //
            styckPerGram: styckPerGram, //
            isFavorite: isFavorite //
        )

        if isEditing { //
            foodData.updateFoodItem(foodItemToSave) //
        } else {
            foodData.addFoodItem(foodItemToSave) //
        }

        dismiss() //
    }
}
