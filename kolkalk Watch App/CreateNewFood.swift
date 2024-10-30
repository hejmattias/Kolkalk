import SwiftUI

struct CreateNewFoodItemView: View {
    @ObservedObject var foodData: FoodData
    @Binding var navigationPath: NavigationPath

    @State private var foodName: String = ""
    @State private var carbsPer100gString: String = ""
    @State private var gramsPerDlString: String = ""
    @State private var styckPerGramString: String = ""
    @State private var isFavorite: Bool = false // Ny State-variabel

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

            // Ny sektion för favoritmarkering
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

    func saveNewFoodItem() {
        guard let carbsPer100g = Double(carbsPer100gString.replacingOccurrences(of: ",", with: ".")) else { return }

        var gramsPerDl: Double? = nil
        if !gramsPerDlString.isEmpty, let gramsPerDlValue = Double(gramsPerDlString.replacingOccurrences(of: ",", with: ".")) {
            gramsPerDl = gramsPerDlValue
        }

        var styckPerGram: Double? = nil
        if !styckPerGramString.isEmpty, let styckPerGramValue = Double(styckPerGramString.replacingOccurrences(of: ",", with: ".")) {
            styckPerGram = styckPerGramValue
        }

        let newFoodItem = FoodItem(
            name: foodName,
            carbsPer100g: carbsPer100g,
            grams: 0,
            gramsPerDl: gramsPerDl,
            styckPerGram: styckPerGram,
            isFavorite: isFavorite // Sätt favoritstatus
        )
        foodData.addFoodItem(newFoodItem)

        navigationPath.removeLast() // Återgå till livsmedelslistan
    }
}

