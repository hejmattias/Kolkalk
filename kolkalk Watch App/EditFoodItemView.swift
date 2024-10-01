import SwiftUI

struct EditFoodItemView: View {
    @ObservedObject var foodData: FoodData
    @Binding var navigationPath: NavigationPath
    var food: FoodItem
    @State private var foodName: String
    @State private var carbsPer100gString: String
    @State private var gramsPerDlString: String
    @State private var styckPerGramString: String

    @State private var showingCarbsNumpad = false
    @State private var showingGramsPerDlNumpad = false
    @State private var showingStyckPerGramNumpad = false

    init(food: FoodItem, foodData: FoodData, navigationPath: Binding<NavigationPath>) {
        self.food = food
        self._foodData = ObservedObject(initialValue: foodData)
        self._navigationPath = navigationPath
        self._foodName = State(initialValue: food.name)
        self._carbsPer100gString = State(initialValue: food.carbsPer100g != nil ? "\(food.carbsPer100g!)" : "")
        self._gramsPerDlString = State(initialValue: food.gramsPerDl != nil ? "\(food.gramsPerDl!)" : "")
        self._styckPerGramString = State(initialValue: food.styckPerGram != nil ? "\(food.styckPerGram!)" : "")
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
                        .foregroundColor(.blue)
                }
            }

            Section(header: Text("g per dl (valfritt)")) {
                Button(action: {
                    showingGramsPerDlNumpad = true
                }) {
                    Text(gramsPerDlString.isEmpty ? "Ange värde" : gramsPerDlString)
                        .foregroundColor(.blue)
                }
            }

            Section(header: Text("g per styck (valfritt)")) {
                Button(action: {
                    showingStyckPerGramNumpad = true
                }) {
                    Text(styckPerGramString.isEmpty ? "Ange värde" : styckPerGramString)
                        .foregroundColor(.blue)
                }
            }

            Section {
                Button("Spara ändringar") {
                    saveChanges()
                }
            }
        }
        .navigationTitle("Redigera livsmedel")
        .sheet(isPresented: $showingCarbsNumpad) {
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
        // Försök att konvertera strängarna till Double
        guard let carbsPer100g = Double(carbsPer100gString.replacingOccurrences(of: ",", with: ".")) else { return }

        var gramsPerDl: Double? = nil
        if !gramsPerDlString.isEmpty, let gramsPerDlValue = Double(gramsPerDlString.replacingOccurrences(of: ",", with: ".")) {
            gramsPerDl = gramsPerDlValue
        }

        var styckPerGram: Double? = nil
        if !styckPerGramString.isEmpty, let styckPerGramValue = Double(styckPerGramString.replacingOccurrences(of: ",", with: ".")) {
            styckPerGram = styckPerGramValue
        }

        // Uppdatera livsmedlets egenskaper
        var updatedFood = food
        updatedFood.name = foodName
        updatedFood.carbsPer100g = carbsPer100g
        updatedFood.gramsPerDl = gramsPerDl
        updatedFood.styckPerGram = styckPerGram

        // Hitta och uppdatera livsmedlet i listan
        if let index = foodData.foodList.firstIndex(where: { $0.id == food.id }) {
            foodData.foodList[index] = updatedFood
        }

        // Spara ändringarna
        foodData.saveToUserDefaults()

        // Återgå till föregående vy
        navigationPath.removeLast()
    }
}
