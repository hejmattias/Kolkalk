// Kolkalk/kolkalk Watch App/CreateFoodFromPlateView.swift
import Foundation
import SwiftUI

struct CreateFoodFromPlateView: View {
    @ObservedObject var plate: Plate // Behövs för CalculatorView init
    @ObservedObject var foodData: FoodData
    @Binding var navigationPath: NavigationPath
    @Environment(\.dismiss) var dismiss

    @State private var foodName: String = ""
    @State private var totalWeightString: String = ""
    @State private var containerWeightString: String = ""
    @State private var calculatedCarbsPer100g: Double?

    // <<< ÄNDRING: Byt State-variabler för sheet-presentation >>>
    @State private var showingTotalWeightCalculator = false
    @State private var showingContainerWeightCalculator = false
    // <<< --- >>>
    @State private var showingChooseContainer = false // Behåll denna

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
                         // <<< ÄNDRING: Ändra knapptext och action >>>
                         Button("Ange/Ändra") { showingTotalWeightCalculator = true }
                    }

                    HStack {
                         Text("Kärlets vikt (g): \(containerWeightString.isEmpty ? "Ange" : containerWeightString)")
                             .foregroundColor(containerWeightString.isEmpty ? .gray : .primary)
                         Spacer()
                         // <<< ÄNDRING: Ändra knapptext och action >>>
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
                    calculateAndSave()
                }
                .disabled(foodName.isEmpty || totalWeightString.isEmpty)
            }
        }
        .navigationTitle("Skapa livsmedel")
        // <<< ÄNDRING START: Använd CalculatorView i numericInput-läge >>>
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
        // <<< ÄNDRING SLUT >>>
        .sheet(isPresented: $showingChooseContainer) { // ChooseContainer är oförändrad
            ChooseContainerView(selectedWeight: $containerWeightString)
        }
        .onAppear {
            // Nollställ vid start eller ladda sparade värden?
            // Låt det vara som det är nu.
        }
    }

    // calculateAndSave (logik oförändrad)
    func calculateAndSave() {
        let netWeight = totalWeight - containerWeight
        guard netWeight > 0 else {
            print("Net weight must be positive")
            // Visa felmeddelande?
            return
        }

        let totalCarbsOnPlate = plate.items.reduce(0) { $0 + $1.totalCarbs }
        guard totalCarbsOnPlate > 0 else {
             print("Cannot create food item with zero carbs on plate.")
             // Visa felmeddelande?
             return
        }

        let carbsPer100g = (totalCarbsOnPlate / netWeight) * 100
        calculatedCarbsPer100g = carbsPer100g // Uppdatera state för visning

        let newFoodItem = FoodItem(
            name: foodName,
            carbsPer100g: carbsPer100g,
            grams: 0 // Gram sätts inte här
        )
        foodData.addFoodItem(newFoodItem)

        plate.emptyPlate() // Töm tallriken efteråt

        // Återgå till rotvyn
         navigationPath = NavigationPath()
    }
}
