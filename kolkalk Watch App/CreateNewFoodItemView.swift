// Kolkalk/kolkalk Watch App/CreateNewFoodItemView.swift
// OBS: Filnamnet i projektet bör vara CreateNewFoodItemView.swift för att matcha struct-namnet
import SwiftUI

struct CreateNewFoodItemView: View {
    @ObservedObject var foodData: FoodData
    @Binding var navigationPath: NavigationPath
    // <<< NYTT: Lägg till Plate som parameter (behövs för CalculatorView init) >>>
    @ObservedObject var plate: Plate // Antag att Plate.shared finns eller skicka in den

    @State private var foodName: String = ""
    @State private var carbsPer100gString: String = ""
    @State private var gramsPerDlString: String = ""
    @State private var styckPerGramString: String = ""
    @State private var isFavorite: Bool = false

    // <<< ÄNDRING: Byt State-variabler för sheet-presentation >>>
    @State private var showingCarbsCalculator = false
    @State private var showingGramsPerDlCalculator = false
    @State private var showingStyckPerGramCalculator = false

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
                Button("Spara") {
                    saveNewFoodItem()
                }
                .disabled(foodName.isEmpty || carbsPer100gString.isEmpty)
            }
        }
        .navigationTitle("Lägg till livsmedel")
        // <<< ÄNDRING START: Använd CalculatorView i numericInput-läge >>>
        .sheet(isPresented: $showingCarbsCalculator) {
            // Använd den anpassade init för CalculatorView
            CalculatorView(
                plate: plate, // Skicka med plate
                navigationPath: $navigationPath, // Skicka med navigationPath (även om den inte används i numericInput)
                mode: .numericInput, // Sätt läget
                outputString: $carbsPer100gString, // Binding till rätt state-variabel
                initialCalculation: carbsPer100gString, // Skicka med nuvarande värde
                inputTitle: "Ange gk per 100g" // Sätt en titel
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

    // saveNewFoodItem (oförändrad logik)
    func saveNewFoodItem() {
        guard let carbsPer100g = Double(carbsPer100gString.replacingOccurrences(of: ",", with: ".")) else {
            print("Error: Invalid carbs value")
            return
        }
        let gramsPerDl = Double(gramsPerDlString.replacingOccurrences(of: ",", with: "."))
        let styckPerGram = Double(styckPerGramString.replacingOccurrences(of: ",", with: "."))

        let newFoodItem = FoodItem(
            name: foodName,
            carbsPer100g: carbsPer100g,
            grams: 0,
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

// <<< NYTT: Lägg till en PreviewProvider om du vill kunna förhandsgranska >>>
/*
 #Preview {
     // Skapa dummy-data för förhandsgranskning
     let foodData = FoodData()
     let plate = Plate.shared // Använd singleton eller skapa en dummy
     @State var path = NavigationPath()

     return NavigationView { // Kan behövas för titeln
         CreateNewFoodItemView(foodData: foodData, navigationPath: $path, plate: plate)
     }
 }
 */
