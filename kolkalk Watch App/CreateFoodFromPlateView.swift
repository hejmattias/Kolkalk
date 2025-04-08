// Kolkalk/kolkalk Watch App/CreateFoodFromPlateView.swift
import Foundation
import SwiftUI

struct CreateFoodFromPlateView: View {
    @ObservedObject var plate: Plate // Behövs för CalculatorView init och för att tömma
    @ObservedObject var foodData: FoodData
    @Binding var navigationPath: NavigationPath
    @Environment(\.dismiss) var dismiss // Används inte direkt, men kan vara bra att ha

    @State private var foodName: String = ""
    @State private var totalWeightString: String = ""
    @State private var containerWeightString: String = ""
    @State private var calculatedCarbsPer100g: Double?

    @State private var showingTotalWeightCalculator = false
    @State private var showingContainerWeightCalculator = false
    @State private var showingChooseContainer = false

    // --- ÄNDRING START: State för att hantera bekräftelsedialogen ---
    @State private var showConfirmationAlert = false
    @State private var newlyCreatedFoodItem: FoodItem? = nil // För att spara det nya objektet temporärt
    @State private var alertMessage = "" // För meddelandet i alerten
    // --- ÄNDRING SLUT ---

    var totalWeight: Double { Double(totalWeightString.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    var containerWeight: Double { Double(containerWeightString.replacingOccurrences(of: ",", with: ".")) ?? 0 }

    var body: some View {
        VStack {
            Form {
                Section(header: Text("Livsmedelsinformation")) {
                    TextField("Livsmedelsnamn", text: $foodName)

                    HStack {
                         Text("Total vikt (g): \(totalWeightString.isEmpty ? "Ange" : totalWeightString)")
                             .foregroundColor(totalWeightString.isEmpty ? .gray : .primary)
                         Spacer()
                         Button("Ange/Ändra") { showingTotalWeightCalculator = true }
                    }

                    HStack {
                         Text("Kärlets vikt (g): \(containerWeightString.isEmpty ? "Ange" : containerWeightString)")
                             .foregroundColor(containerWeightString.isEmpty ? .gray : .primary)
                         Spacer()
                         Button("Ange/Ändra") { showingContainerWeightCalculator = true }
                    }

                    HStack {
                        Spacer()
                        Button("Välj kärl") { showingChooseContainer = true }
                            .foregroundColor(.blue)
                        Spacer()
                    }
                }

                if let carbsPer100g = calculatedCarbsPer100g {
                    Section(header: Text("Beräknat kolhydrater per 100g")) {
                        Text("\(carbsPer100g, specifier: "%.1f") g/100g")
                    }
                }

                Button("Beräkna och spara") {
                    calculateAndPrepareToSave() // <<< ÄNDRAT FUNKTIONSANROP
                }
                .disabled(foodName.isEmpty || totalWeightString.isEmpty || plate.items.isEmpty) // <<< Lägg till kontroll om tallriken är tom
            }
        }
        .navigationTitle("Skapa livsmedel")
        .sheet(isPresented: $showingTotalWeightCalculator) {
            CalculatorView(
                plate: plate,
                navigationPath: $navigationPath,
                mode: .numericInput,
                outputString: $totalWeightString,
                initialCalculation: totalWeightString,
                inputTitle: "Ange total vikt"
            )
        }
        .sheet(isPresented: $showingContainerWeightCalculator) {
            CalculatorView(
                plate: plate,
                navigationPath: $navigationPath,
                mode: .numericInput,
                outputString: $containerWeightString,
                initialCalculation: containerWeightString,
                inputTitle: "Ange kärlets vikt"
            )
        }
        .sheet(isPresented: $showingChooseContainer) {
            ChooseContainerView(selectedWeight: $containerWeightString)
        }
        // --- ÄNDRING START: Lägg till .alert modifier för bekräftelse ---
        .alert("Livsmedel Sparat", isPresented: $showConfirmationAlert, presenting: newlyCreatedFoodItem) { foodItem in
            // Knappar i alerten
            Button("Töm tallriken") {
                plate.emptyPlate() // Töm tallriken
                navigateBack()     // Navigera sedan tillbaka
            }
            Button("Behåll tallriken", role: .cancel) { // Använd .cancel för den mindre destruktiva åtgärden
                navigateBack()     // Navigera tillbaka utan att tömma
            }
        } message: { foodItem in
            // Meddelandet i alerten
            Text("Livsmedlet \"\(foodItem.name)\" med \(foodItem.carbsPer100g ?? 0, specifier: "%.1f") gk/100g är sparat. Vill du tömma tallriken nu?")
        }
        // --- ÄNDRING SLUT ---
        .onAppear {
            // Återställ eventuellt beräknat värde om vyn visas igen
            calculatedCarbsPer100g = nil
        }
    }

    // --- ÄNDRING START: Uppdelad funktion för att hantera logiken innan alerten visas ---
    func calculateAndPrepareToSave() {
        let netWeight = totalWeight - containerWeight
        guard netWeight > 0 else {
            print("Net weight must be positive")
            // Visa felmeddelande för användaren här istället? T.ex. en alert.
            // För enkelhetens skull loggar vi bara nu.
            return
        }

        let totalCarbsOnPlate = plate.items.reduce(0) { $0 + $1.totalCarbs }
        guard totalCarbsOnPlate > 0 else {
             print("Cannot create food item with zero carbs on plate.")
             // Visa felmeddelande?
             return
        }

        // Behåll beräkningen
        let carbsPer100g = (totalCarbsOnPlate / netWeight) * 100
        calculatedCarbsPer100g = carbsPer100g // Uppdatera state för visning (kan tas bort om det inte behövs i UI)

        // Skapa det nya livsmedlet
        let newFoodItem = FoodItem(
            name: foodName.trimmingCharacters(in: .whitespacesAndNewlines), // Trimma namnet
            carbsPer100g: carbsPer100g,
            grams: 0 // Gram sätts inte här, det är ett livsmedel i listan
            // Inga andra värden som gramsPerDl eller styckPerGram sätts från tallriken
        )

        // Lägg till i FoodData
        foodData.addFoodItem(newFoodItem)
        print("Nytt livsmedel sparat lokalt: \(newFoodItem.name)") // För felsökning

        // Spara det nyskapade objektet för att använda i alerten
        self.newlyCreatedFoodItem = newFoodItem

        // Sätt flaggan för att visa alerten
        self.showConfirmationAlert = true

        // Ta bort tömning och navigering härifrån! Det sköts av alertens knappar.
        // plate.emptyPlate() // <<< TAS BORT HÄRIFRÅN
        // navigateBack()     // <<< TAS BORT HÄRIFRÅN
    }

    // Hjälpfunktion för att navigera tillbaka till rotvyn
    func navigateBack() {
        navigationPath = NavigationPath() // Nollställ stacken
    }
    // --- ÄNDRING SLUT ---
}
