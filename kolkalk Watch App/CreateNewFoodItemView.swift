//
//  CreateNewFoodItemView.swift
//  Kolkalk
//
//  Created by Mattias Göransson on 2025-04-03.
//


// Kolkalk.zip/kolkalk Watch App/CreateNewFood.swift
// OBS: Filnamnet i projektet bör vara CreateNewFoodItemView.swift för att matcha struct-namnet
import SwiftUI

struct CreateNewFoodItemView: View {
    @ObservedObject var foodData: FoodData
    @Binding var navigationPath: NavigationPath

    @State private var foodName: String = ""
    @State private var carbsPer100gString: String = ""
    @State private var gramsPerDlString: String = ""
    @State private var styckPerGramString: String = ""
    @State private var isFavorite: Bool = false

    @State private var showingCarbsNumpad = false
    @State private var showingGramsPerDlNumpad = false
    @State private var showingStyckPerGramNumpad = false

    var body: some View {
        Form {
            Section(header: Text("Livsmedelsnamn")) {
                TextField("Livsmedelsnamn", text: $foodName)
            }

            Section(header: Text("gk per 100g")) {
                Button(action: {
                    showingCarbsNumpad = true
                }) {
                    // <<< CHANGE START >>>
                    // Visa värdet eller platshållare
                    Text(carbsPer100gString.isEmpty ? "Ange värde" : carbsPer100gString)
                        .foregroundColor(carbsPer100gString.isEmpty ? .gray : .primary)
                    // <<< CHANGE END >>>
                }
            }

            Section(header: Text("g per dl (valfritt)")) {
                Button(action: {
                    showingGramsPerDlNumpad = true
                }) {
                     // <<< CHANGE START >>>
                     Text(gramsPerDlString.isEmpty ? "Ange värde" : gramsPerDlString)
                         .foregroundColor(gramsPerDlString.isEmpty ? .gray : .primary)
                     // <<< CHANGE END >>>
                }
            }

            Section(header: Text("g per styck (valfritt)")) {
                Button(action: {
                    showingStyckPerGramNumpad = true
                }) {
                     // <<< CHANGE START >>>
                     Text(styckPerGramString.isEmpty ? "Ange värde" : styckPerGramString)
                         .foregroundColor(styckPerGramString.isEmpty ? .gray : .primary)
                     // <<< CHANGE END >>>
                }
            }

            Section {
                Toggle(isOn: $isFavorite) {
                    Text("Favorit")
                }
            }

            Section {
                Button("Spara") {
                    saveNewFoodItem()
                }
                .disabled(foodName.isEmpty || carbsPer100gString.isEmpty)
            }
        }
        .navigationTitle("Lägg till livsmedel")
        // <<< CHANGE START >>>
        // Använd NumpadView i numericValue-läge i .sheet
        .sheet(isPresented: $showingCarbsNumpad) {
            NumpadView(valueString: $carbsPer100gString, title: "Ange gk per 100g", mode: .numericValue)
        }
        .sheet(isPresented: $showingGramsPerDlNumpad) {
            NumpadView(valueString: $gramsPerDlString, title: "Ange g per dl", mode: .numericValue)
        }
        .sheet(isPresented: $showingStyckPerGramNumpad) {
            NumpadView(valueString: $styckPerGramString, title: "Ange g per styck", mode: .numericValue)
        }
         // <<< CHANGE END >>>
    }

    func saveNewFoodItem() {
        // Konvertera strängar till Double (oförändrat)
        guard let carbsPer100g = Double(carbsPer100gString.replacingOccurrences(of: ",", with: ".")) else {
            print("Error: Invalid carbs value")
            return
        }

        let gramsPerDl = Double(gramsPerDlString.replacingOccurrences(of: ",", with: "."))
        let styckPerGram = Double(styckPerGramString.replacingOccurrences(of: ",", with: "."))

        let newFoodItem = FoodItem(
            name: foodName,
            carbsPer100g: carbsPer100g,
            grams: 0, // Gram sätts när det läggs på tallriken
            gramsPerDl: gramsPerDl,
            styckPerGram: styckPerGram,
            isFavorite: isFavorite
        )
        foodData.addFoodItem(newFoodItem)

        if navigationPath.count > 0 {
            navigationPath.removeLast() // Återgå
        }
    }
}