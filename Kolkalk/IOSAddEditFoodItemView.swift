//
//  IOSAddEditFoodItemView.swift
//  Kolkalk
//
//  Created by Mattias Göransson on 2025-04-01.
//


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

    // För att visa felmeddelande
    @State private var errorMessage: String? = nil

    var isEditing: Bool { foodToEdit != nil }

    var body: some View {
        Form {
            Section(header: Text("Detaljer")) {
                TextField("Namn", text: $name)
                HStack {
                     TextField("Kolhydrater (gk per 100g)", text: $carbsPer100gString)
                         .keyboardType(.decimalPad)
                     Text("gk/100g").foregroundColor(.gray)
                 }
                 HStack {
                     TextField("Vikt per dl (valfritt)", text: $gramsPerDlString)
                         .keyboardType(.decimalPad)
                     Text("g/dl").foregroundColor(.gray)
                 }
                 HStack {
                     TextField("Vikt per styck (valfritt)", text: $styckPerGramString)
                         .keyboardType(.decimalPad)
                     Text("g/st").foregroundColor(.gray)
                 }
                Toggle("Favorit", isOn: $isFavorite)
            }

            // Visa felmeddelande om det finns
            if let message = errorMessage {
                 Section {
                     Text(message)
                         .foregroundColor(.red)
                 }
             }
        }
        .navigationTitle(isEditing ? "Redigera livsmedel" : "Lägg till livsmedel")
        .navigationBarItems(leading: Button("Avbryt") { dismiss() },
                            trailing: Button("Spara") { saveFoodItem() })
        .onAppear {
            // Fyll i fälten om vi redigerar
            if let food = foodToEdit {
                name = food.name
                carbsPer100gString = String(food.carbsPer100g ?? 0)
                gramsPerDlString = food.gramsPerDl != nil ? String(food.gramsPerDl!) : ""
                styckPerGramString = food.styckPerGram != nil ? String(food.styckPerGram!) : ""
                isFavorite = food.isFavorite
            }
        }
    }

    func saveFoodItem() {
        // Validering
        guard !name.isEmpty else {
            errorMessage = "Namn får inte vara tomt."
            return
        }
        guard let carbsPer100g = Double(carbsPer100gString.replacingOccurrences(of: ",", with: ".")) else {
            errorMessage = "Ange ett giltigt värde för kolhydrater."
            return
        }

        let gramsPerDl = Double(gramsPerDlString.replacingOccurrences(of: ",", with: "."))
        let styckPerGram = Double(styckPerGramString.replacingOccurrences(of: ",", with: "."))

        errorMessage = nil // Rensa eventuellt tidigare felmeddelande

        let foodItemToSave = FoodItem(
            id: foodToEdit?.id ?? UUID(), // Använd befintligt ID vid redigering
            name: name,
            carbsPer100g: carbsPer100g,
            grams: 0, // Irrelevant för listan
            gramsPerDl: gramsPerDl,
            styckPerGram: styckPerGram,
            isFavorite: isFavorite
        )

        if isEditing {
            foodData.updateFoodItem(foodItemToSave)
        } else {
            foodData.addFoodItem(foodItemToSave)
        }

        dismiss() // Stäng vyn efter sparande
    }
}