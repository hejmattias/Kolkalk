// Kolkalk.zip/kolkalk Watch App/CreateFoodFromPlateView.swift
import Foundation
import SwiftUI

struct CreateFoodFromPlateView: View {
    @ObservedObject var plate: Plate
    @ObservedObject var foodData: FoodData
    @Binding var navigationPath: NavigationPath
    @Environment(\.dismiss) var dismiss

    @State private var foodName: String = ""
    @State private var totalWeightString: String = ""
    @State private var containerWeightString: String = ""
    @State private var calculatedCarbsPer100g: Double?
    @State private var showingTotalWeightInput = false
    @State private var showingContainerWeightInput = false
    @State private var showingChooseContainer = false

    var totalWeight: Double { Double(totalWeightString.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    var containerWeight: Double { Double(containerWeightString.replacingOccurrences(of: ",", with: ".")) ?? 0 }

    var body: some View {
        VStack {
            Form {
                Section(header: Text("Livsmedelsinformation")) {
                    TextField("Livsmedelsnamn", text: $foodName)

                    HStack {
                         // <<< CHANGE START >>>
                         // Visa värdet eller platshållare
                         Text("Total vikt (g): \(totalWeightString.isEmpty ? "Ange" : totalWeightString)")
                             .foregroundColor(totalWeightString.isEmpty ? .gray : .primary)
                         // <<< CHANGE END >>>
                        Spacer()
                        Button("Ange") { showingTotalWeightInput = true }
                    }

                    HStack {
                         // <<< CHANGE START >>>
                         Text("Kärlets vikt (g): \(containerWeightString.isEmpty ? "Ange" : containerWeightString)")
                             .foregroundColor(containerWeightString.isEmpty ? .gray : .primary)
                         // <<< CHANGE END >>>
                        Spacer()
                        Button("Ange") { showingContainerWeightInput = true }
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
                .disabled(foodName.isEmpty || totalWeightString.isEmpty) // Ändrat till string check
            }
        }
        .navigationTitle("Skapa livsmedel")
        // <<< CHANGE START >>>
        // Använd NumpadView i numericValue-läge i .sheet
        .sheet(isPresented: $showingTotalWeightInput) {
            NumpadView(valueString: $totalWeightString, title: "Ange total vikt", mode: .numericValue)
        }
        .sheet(isPresented: $showingContainerWeightInput) {
            NumpadView(valueString: $containerWeightString, title: "Ange kärlets vikt", mode: .numericValue)
        }
        // <<< CHANGE END >>>
        .sheet(isPresented: $showingChooseContainer) { // ChooseContainer är oförändrad
            ChooseContainerView(selectedWeight: $containerWeightString)
        }
    }

    // calculateAndSave (logik oförändrad)
    func calculateAndSave() {
        let netWeight = totalWeight - containerWeight
        guard netWeight > 0 else {
            print("Net weight must be positive")
            // Kanske visa felmeddelande för användaren
            return
        }

        let totalCarbs = plate.items.reduce(0) { $0 + $1.totalCarbs }
        let carbsPer100g = (totalCarbs / netWeight) * 100

        calculatedCarbsPer100g = carbsPer100g

        let newFoodItem = FoodItem(name: foodName, carbsPer100g: carbsPer100g, grams: 0, gramsPerDl: nil)
        foodData.addFoodItem(newFoodItem)

        plate.emptyPlate()

        // Återgå till rotvyn
         navigationPath = NavigationPath() // Nollställ stacken
         // Om dismiss() behövs beror på hur denna vy presenteras. Om den är i en NavigationStack,
         // kommer ovanstående rad att ta användaren till rotvyn.
         // dismiss() // Tas bort om den är i stacken
    }
}
