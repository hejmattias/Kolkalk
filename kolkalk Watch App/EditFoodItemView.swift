// Kolkalk.zip/kolkalk Watch App/EditFoodItemView.swift
import SwiftUI

struct EditFoodItemView: View {
    @ObservedObject var foodData: FoodData
    @Binding var navigationPath: NavigationPath
    var food: FoodItem // Det FoodItem vi redigerar

    @State private var foodName: String
    @State private var carbsPer100gString: String
    @State private var gramsPerDlString: String
    @State private var styckPerGramString: String
    @State private var isFavorite: Bool

    @State private var showingCarbsNumpad = false
    @State private var showingGramsPerDlNumpad = false
    @State private var showingStyckPerGramNumpad = false

    // Init (oförändrad)
    init(food: FoodItem, foodData: FoodData, navigationPath: Binding<NavigationPath>) {
        self.food = food
        self._foodData = ObservedObject(initialValue: foodData)
        self._navigationPath = navigationPath
        self._foodName = State(initialValue: food.name)
        self._carbsPer100gString = State(initialValue: food.carbsPer100g != nil ? String(format: "%.1f", food.carbsPer100g!).replacingOccurrences(of: ".", with: ",") : "")
        self._gramsPerDlString = State(initialValue: food.gramsPerDl != nil ? String(format: "%.1f", food.gramsPerDl!).replacingOccurrences(of: ".", with: ",") : "")
        self._styckPerGramString = State(initialValue: food.styckPerGram != nil ? String(format: "%.1f", food.styckPerGram!).replacingOccurrences(of: ".", with: ",") : "")
        self._isFavorite = State(initialValue: food.isFavorite)
    }

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
                Button("Spara ändringar") {
                    saveChanges()
                }
                 .disabled(foodName.isEmpty || carbsPer100gString.isEmpty)
            }
        }
        .navigationTitle("Redigera livsmedel")
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

    // saveChanges (oförändrad logik, konverterar strängar)
    private func saveChanges() {
        guard let carbsPer100g = Double(carbsPer100gString.replacingOccurrences(of: ",", with: ".")) else {
             print("Fel: Ogiltigt värde för kolhydrater.")
             return
        }
        let gramsPerDl = Double(gramsPerDlString.replacingOccurrences(of: ",", with: "."))
        let styckPerGram = Double(styckPerGramString.replacingOccurrences(of: ",", with: "."))

        let updatedFood = FoodItem(
            id: food.id,
            name: foodName,
            carbsPer100g: carbsPer100g,
            grams: food.grams,
            gramsPerDl: gramsPerDl,
            styckPerGram: styckPerGram,
            inputUnit: food.inputUnit,
            isDefault: food.isDefault,
            hasBeenLogged: food.hasBeenLogged,
            isFavorite: isFavorite,
            isCalculatorItem: food.isCalculatorItem
        )
        foodData.updateFoodItem(updatedFood)

        if navigationPath.count > 0 {
             navigationPath.removeLast()
        }
    }
}
