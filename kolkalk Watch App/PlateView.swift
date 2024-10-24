// kolkalk Watch App/PlateView.swift

import Foundation
import SwiftUI
import HealthKit // Importera HealthKit

struct PlateView: View {
    @ObservedObject var plate: Plate
    @Binding var navigationPath: NavigationPath
    @State private var showDetailsForItemId: UUID?
    
    // State-variabler för HealthKit-loggning
    @State private var isLogging = false
    @State private var logSuccess = false
    @State private var showLogAlert = false

    // State-variabel för bekräftelse-alert
    @State private var showEmptyConfirmation = false

    var totalCarbs: Double {
        plate.items.reduce(0) { $0 + $1.totalCarbs }
    }

    var body: some View {
        List {
            ForEach(plate.items) { item in
                VStack(alignment: .leading) {
                    HStack {
                        NavigationLink(destination: EditFoodView(plate: plate, item: item)) {
                            Text(item.name)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        Spacer()
                        Text("\(item.totalCarbs, specifier: "%.1f") gk")
                    }

                    // Visa detaljer när användaren sveper
                    if showDetailsForItemId == item.id {
                        Text(itemDetailString(for: item))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 50, coordinateSpace: .local)
                        .onEnded { value in
                            if value.translation.width > 0 {
                                // Svep från vänster till höger för att visa information
                                showDetailsForItemId = item.id
                            } else if value.translation.width < 0 {
                                // Svep från höger till vänster för att dölja information
                                showDetailsForItemId = nil
                            }
                        }
                )
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        deleteItem(item: item)
                    } label: {
                        Label("Ta bort", systemImage: "trash")
                    }
                }
            }

            if !plate.items.isEmpty {
                Button(action: {
                    showEmptyConfirmation = true // Visa bekräftelse-alert
                }) {
                    HStack {
                        Spacer()
                        Text("Töm tallriken")
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
                .alert("Bekräfta Töm Tallriken", isPresented: $showEmptyConfirmation) {
                    Button("Ja", role: .destructive) {
                        plate.emptyPlate()
                    }
                    Button("Avbryt", role: .cancel) { }
                } message: {
                    Text("Är du säker på att du vill tömma tallriken?")
                }

                // "Logga till Apple Hälsa"-knappen
                Button(action: {
                    logToHealth()
                }) {
                    HStack {
                        Spacer()
                        Text("Logga till Apple Hälsa")
                            .foregroundColor(.blue)
                        Spacer()
                    }
                }
                .disabled(isLogging)
            } else {
                // Visa meddelande om tallriken är tom
                Text("Tallriken är tom")
                    .foregroundColor(.gray)
            }
        }
        .navigationTitle("Totalt: \(totalCarbs, specifier: "%.1f") gk")
        .onDisappear {
            showDetailsForItemId = nil
        }
        .alert(isPresented: $showLogAlert) {
            if logSuccess {
                return Alert(
                    title: Text("Lyckades"),
                    message: Text("Data har loggats till Apple Hälsa."),
                    dismissButton: .default(Text("OK"))
                )
            } else {
                return Alert(
                    title: Text("Misslyckades"),
                    message: Text("Kunde inte logga data till Apple Hälsa."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    // MARK: - Hjälpmetoder

    private func deleteItem(item: FoodItem) {
        if let index = plate.items.firstIndex(where: { $0.id == item.id }) {
            plate.items.remove(at: index)
            plate.saveToUserDefaults()
        }
    }

    private func itemDetailString(for item: FoodItem) -> String {
        let gramsString = "\(String(format: "%.1f", item.grams))g"

        guard let inputUnit = item.inputUnit else {
            return gramsString
        }

        let inputValue: Double
        let unitString: String

        switch inputUnit {
        case "g":
            inputValue = item.grams
            unitString = "g"
        case "dl":
            if let gramsPerDl = item.gramsPerDl, gramsPerDl > 0 {
                inputValue = item.grams / gramsPerDl
                unitString = "dl"
            } else {
                return gramsString
            }
        case "st":
            if let styckPerGram = item.styckPerGram, styckPerGram > 0 {
                inputValue = item.grams / styckPerGram
                unitString = "st"
            } else {
                return gramsString
            }
        default:
            return gramsString
        }

        if unitString == "g" {
            return "\(String(format: "%.1f", inputValue))\(unitString)"
        } else {
            return "\(String(format: "%.1f", inputValue))\(unitString) (\(gramsString))"
        }
    }

    // Funktion för att logga till HealthKit
    private func logToHealth() {
        isLogging = true

        // Skapa metadata med livsmedel och mängder
        let foodDetails = plate.items.map { item in
            "\(item.name): \(item.formattedDetail())"
        }.joined(separator: "; ")

        let metadata = [
            HKMetadataKeyFoodType: foodDetails
        ]

        HealthKitManager.shared.logCarbohydrates(totalCarbs: totalCarbs, metadata: metadata) { success, error in
            DispatchQueue.main.async {
                self.isLogging = false
                self.logSuccess = success
                self.showLogAlert = true

                if let error = error {
                    print("Fel vid loggning till HealthKit: \(error.localizedDescription)")
                }
            }
        }
    }
}
