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

    var totalWeight: Double {
        Double(totalWeightString.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    var containerWeight: Double {
        Double(containerWeightString.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    var body: some View {
        VStack {
            Form {
                Section(header: Text("Livsmedelsinformation")) {
                    TextField("Livsmedelsnamn", text: $foodName)

                    HStack {
                        Text("Total vikt (g): \(totalWeightString)")
                        Spacer()
                        Button("Ange") {
                            showingTotalWeightInput = true
                        }
                    }

                    HStack {
                        Text("Kärlets vikt (g): \(containerWeightString)")
                        Spacer()
                        Button("Ange") {
                            showingContainerWeightInput = true
                        }
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
                .disabled(foodName.isEmpty || totalWeight == 0)
            }
        }
        .navigationTitle("Skapa livsmedel")
        .sheet(isPresented: $showingTotalWeightInput) {
            InputValueDoubleView(value: $totalWeightString, title: "Ange total vikt")
        }
        .sheet(isPresented: $showingContainerWeightInput) {
            InputValueDoubleView(value: $containerWeightString, title: "Ange kärlets vikt")
        }
    }

    func calculateAndSave() {
        let netWeight = totalWeight - containerWeight
        guard netWeight > 0 else { return }

        let totalCarbs = plate.items.reduce(0) { $0 + $1.totalCarbs }
        let carbsPer100g = (totalCarbs / netWeight) * 100

        calculatedCarbsPer100g = carbsPer100g

        let newFoodItem = FoodItem(name: foodName, carbsPer100g: carbsPer100g, grams: 0, gramsPerDl: nil)
        foodData.addFoodItem(newFoodItem)

        plate.emptyPlate()

        navigationPath = NavigationPath()
    }
}
