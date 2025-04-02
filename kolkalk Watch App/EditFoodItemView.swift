// Kolkalk.zip/kolkalk Watch App/EditFoodItemView.swift

import SwiftUI

struct EditFoodItemView: View {
    // *** ÄNDRING: Ändra från @ObservedObject till @EnvironmentObject om den skickas så,
    // eller behåll @ObservedObject om den skickas direkt i konstruktorn.
    // Vi antar att den skickas via konstruktorn som i förra steget. ***
    @ObservedObject var foodData: FoodData

    @Binding var navigationPath: NavigationPath
    var food: FoodItem // Det FoodItem vi redigerar

    // State för fälten
    @State private var foodName: String
    @State private var carbsPer100gString: String
    @State private var gramsPerDlString: String
    @State private var styckPerGramString: String
    @State private var isFavorite: Bool

    // State för numpad-visning
    @State private var showingCarbsNumpad = false
    @State private var showingGramsPerDlNumpad = false
    @State private var showingStyckPerGramNumpad = false

    // Anpassad init för att sätta initiala State-värden från food-objektet
    init(food: FoodItem, foodData: FoodData, navigationPath: Binding<NavigationPath>) {
        self.food = food
        self._foodData = ObservedObject(initialValue: foodData)
        self._navigationPath = navigationPath
        // Initiera State-variabler från det food-objekt som skickades in
        self._foodName = State(initialValue: food.name)
        self._carbsPer100gString = State(initialValue: food.carbsPer100g != nil ? String(format: "%.1f", food.carbsPer100g!).replacingOccurrences(of: ".", with: ",") : "") // Formatera för visning
        self._gramsPerDlString = State(initialValue: food.gramsPerDl != nil ? String(format: "%.1f", food.gramsPerDl!).replacingOccurrences(of: ".", with: ",") : "") // Formatera
        self._styckPerGramString = State(initialValue: food.styckPerGram != nil ? String(format: "%.1f", food.styckPerGram!).replacingOccurrences(of: ".", with: ",") : "") // Formatera
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
                    Text(carbsPer100gString.isEmpty ? "Ange värde" : carbsPer100gString)
                        .foregroundColor(carbsPer100gString.isEmpty ? .gray : .primary) // Grå om tom
                }
            }

            Section(header: Text("g per dl (valfritt)")) {
                Button(action: {
                    showingGramsPerDlNumpad = true
                }) {
                    Text(gramsPerDlString.isEmpty ? "Ange värde" : gramsPerDlString)
                         .foregroundColor(gramsPerDlString.isEmpty ? .gray : .primary) // Grå om tom
                }
            }

            Section(header: Text("g per styck (valfritt)")) {
                Button(action: {
                    showingStyckPerGramNumpad = true
                }) {
                    Text(styckPerGramString.isEmpty ? "Ange värde" : styckPerGramString)
                         .foregroundColor(styckPerGramString.isEmpty ? .gray : .primary) // Grå om tom
                }
            }

            // Sektion för favoritmarkering
            Section {
                Toggle(isOn: $isFavorite) {
                    Text("Favorit")
                }
            }

            Section {
                Button("Spara ändringar") {
                    saveChanges()
                }
                 // Inaktivera om namn eller kolhydrater saknas
                 .disabled(foodName.isEmpty || carbsPer100gString.isEmpty)
            }
        }
        .navigationTitle("Redigera livsmedel")
        .sheet(isPresented: $showingCarbsNumpad) {
            // Skicka med Double-formaterad sträng
            InputValueDoubleView(value: $carbsPer100gString, title: "Ange gk per 100g")
        }
        .sheet(isPresented: $showingGramsPerDlNumpad) {
             InputValueDoubleView(value: $gramsPerDlString, title: "Ange g per dl")
        }
        .sheet(isPresented: $showingStyckPerGramNumpad) {
             InputValueDoubleView(value: $styckPerGramString, title: "Ange g per styck")
        }
    }

    private func saveChanges() {
        // Försök att konvertera strängarna till Double, ersätt kommatecken
        guard let carbsPer100g = Double(carbsPer100gString.replacingOccurrences(of: ",", with: ".")) else {
             print("Fel: Ogiltigt värde för kolhydrater.")
             // Visa ev. felmeddelande för användaren här
             return
        }

        // Konvertera valfria fält, nil om tomma eller ogiltiga
        let gramsPerDl = Double(gramsPerDlString.replacingOccurrences(of: ",", with: "."))
        let styckPerGram = Double(styckPerGramString.replacingOccurrences(of: ",", with: "."))


        // Skapa ett uppdaterat FoodItem-objekt baserat på State-variablerna
        // Använd det ursprungliga ID:t från `food`-objektet vi redigerar.
        let updatedFood = FoodItem(
            id: food.id, // Behåll samma ID!
            name: foodName,
            carbsPer100g: carbsPer100g,
            grams: food.grams, // Gram är transient och redigeras inte här
            gramsPerDl: gramsPerDl,
            styckPerGram: styckPerGram,
            inputUnit: food.inputUnit, // Behåll ursprunglig inputUnit
            isDefault: food.isDefault, // Behåll ursprungligt isDefault
            hasBeenLogged: food.hasBeenLogged, // Behåll ursprungligt hasBeenLogged
            isFavorite: isFavorite, // Uppdatera favoritstatus
            isCalculatorItem: food.isCalculatorItem // Behåll ursprungligt isCalculatorItem
        )


        // *** ÄNDRING: Anropa den nya uppdateringsmetoden istället för saveToUserDefaults ***
        foodData.updateFoodItem(updatedFood)

        // *** ÄNDRING: Ta bort den lokala uppdateringen här. Den sker nu i FoodData.swift ***
        // if let index = foodData.foodList.firstIndex(where: { $0.id == food.id }) {
        //     foodData.foodList[index] = updatedFood
        // }
        // foodData.saveToUserDefaults() // Borttagen

        // Återgå till föregående vy (troligen FoodListView)
        if navigationPath.count > 0 {
             navigationPath.removeLast()
        }
    }
}
