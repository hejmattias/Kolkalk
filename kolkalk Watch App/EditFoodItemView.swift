// Kolkalk/kolkalk Watch App/EditFoodItemView.swift
import SwiftUI

struct EditFoodItemView: View {
    @ObservedObject var foodData: FoodData
    @Binding var navigationPath: NavigationPath
    // <<< NYTT: Lägg till Plate som parameter >>>
    @ObservedObject var plate: Plate // Antag att Plate.shared finns eller skicka in den
    var food: FoodItem

    @State private var foodName: String
    @State private var carbsPer100gString: String
    @State private var gramsPerDlString: String
    @State private var styckPerGramString: String
    @State private var isFavorite: Bool

    // <<< ÄNDRING: Byt State-variabler för sheet-presentation >>>
    @State private var showingCarbsCalculator = false
    @State private var showingGramsPerDlCalculator = false
    @State private var showingStyckPerGramCalculator = false

    // <<< ÄNDRING: Uppdatera init för att ta emot plate >>>
    init(food: FoodItem, foodData: FoodData, navigationPath: Binding<NavigationPath>, plate: Plate) {
        self.food = food
        self._foodData = ObservedObject(initialValue: foodData)
        self._navigationPath = navigationPath
        self._plate = ObservedObject(initialValue: plate) // Initiera plate

        // Behåll befintlig initiering av State-variabler
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
                    // <<< ÄNDRING: Visa kalkylatorn >>>
                    showingCarbsCalculator = true
                }) {
                     Text(carbsPer100gString.isEmpty ? "Ange värde" : carbsPer100gString)
                         .foregroundColor(carbsPer100gString.isEmpty ? .gray : .primary)
                }
            }

            Section(header: Text("g per dl (valfritt)")) {
                Button(action: {
                    // <<< ÄNDRING: Visa kalkylatorn >>>
                    showingGramsPerDlCalculator = true
                }) {
                     Text(gramsPerDlString.isEmpty ? "Ange värde" : gramsPerDlString)
                          .foregroundColor(gramsPerDlString.isEmpty ? .gray : .primary)
                }
            }

            Section(header: Text("g per styck (valfritt)")) {
                Button(action: {
                    // <<< ÄNDRING: Visa kalkylatorn >>>
                    showingStyckPerGramCalculator = true
                }) {
                    Text(styckPerGramString.isEmpty ? "Ange värde" : styckPerGramString)
                         .foregroundColor(styckPerGramString.isEmpty ? .gray : .primary)
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
        // <<< ÄNDRING START: Använd CalculatorView i numericInput-läge >>>
        .sheet(isPresented: $showingCarbsCalculator) {
            CalculatorView(
                plate: plate,
                navigationPath: $navigationPath,
                mode: .numericInput,
                outputString: $carbsPer100gString,
                initialCalculation: carbsPer100gString,
                inputTitle: "Ange gk per 100g"
            )
        }
        .sheet(isPresented: $showingGramsPerDlCalculator) {
             CalculatorView(
                 plate: plate,
                 navigationPath: $navigationPath,
                 mode: .numericInput,
                 outputString: $gramsPerDlString,
                 initialCalculation: gramsPerDlString,
                 inputTitle: "Ange g per dl"
             )
        }
        .sheet(isPresented: $showingStyckPerGramCalculator) {
             CalculatorView(
                 plate: plate,
                 navigationPath: $navigationPath,
                 mode: .numericInput,
                 outputString: $styckPerGramString,
                 initialCalculation: styckPerGramString,
                 inputTitle: "Ange g per styck"
             )
        }
        // <<< ÄNDRING SLUT >>>
    }

    // saveChanges (oförändrad logik)
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
            grams: food.grams, // Behåll ursprungliga gram (redigeras inte här)
            gramsPerDl: gramsPerDl,
            styckPerGram: styckPerGram,
            inputUnit: food.inputUnit, // Behåll ursprunglig enhet
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
