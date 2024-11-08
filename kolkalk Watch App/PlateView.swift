// PlateView.swift

import SwiftUI
import HealthKit

struct PlateView: View {
    @ObservedObject var plate: Plate
    @Binding var navigationPath: NavigationPath
    @State private var showDetailsForItemId: UUID?

    // State variables for HealthKit logging
    @State private var isLogging = false
    @State private var logAlert: LogAlert?

    // State variable for confirmation alert
    @State private var showEmptyConfirmation = false

    var totalCarbs: Double {
        plate.items.reduce(0) { $0 + $1.totalCarbs }
    }

    // Structure to handle alerts
    struct LogAlert: Identifiable {
        var id = UUID()
        var title: String
        var message: String
    }

    var body: some View {
        List {
            ForEach(plate.items) { item in
                VStack(alignment: .leading) {
                    HStack {
                        NavigationLink(value: Route.editPlateItem(item)) {
                            HStack {
                                Text(item.name)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                if item.hasBeenLogged {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        Spacer()
                        Text("\(item.totalCarbs, specifier: "%.1f") gk")
                    }

                    // Show details when the user swipes
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
                                // Swipe from left to right to show information
                                showDetailsForItemId = item.id
                            } else if value.translation.width < 0 {
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
                    showEmptyConfirmation = true // Show confirmation alert
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

                // "Log to Apple Health" button
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
                .disabled(isLogging || plate.items.allSatisfy { $0.hasBeenLogged })
            } else {
                // Display message when the plate is empty
                Text("Tallriken är tom")
                    .foregroundColor(.gray)
            }

            // Button to log insulin to Apple Health
            Button(action: {
                navigationPath.append(Route.insulinLoggingView)
            }) {
                HStack {
                    Spacer()
                    Text("Logga insulin till Apple Hälsa")
                        .foregroundColor(.blue)
                    Spacer()
                }
            }
        }
        .navigationTitle("Totalt: \(totalCarbs, specifier: "%.1f") gk")
        .onDisappear {
            showDetailsForItemId = nil
        }
        .alert(item: $logAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Helper Methods

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

    // Function to log to HealthKit
    private func logToHealth() {
        isLogging = true

        // Filter out food items that haven't been logged
        let itemsToLog = plate.items.filter { !$0.hasBeenLogged }

        guard !itemsToLog.isEmpty else {
            isLogging = false
            self.logAlert = LogAlert(title: "Inget att logga", message: "Det finns inga nya livsmedel att logga.")
            return
        }

        let totalCarbsToLog = itemsToLog.reduce(0) { $0 + $1.totalCarbs }

        // Create metadata with food items and quantities
        let foodDetails = itemsToLog.map { item in
            "\(item.name): \(item.formattedDetail())"
        }.joined(separator: "; ")

        let metadata = [
            HKMetadataKeyFoodType: foodDetails
        ]

        HealthKitManager.shared.logCarbohydrates(totalCarbs: totalCarbsToLog, metadata: metadata) { success, error in
            DispatchQueue.main.async {
                self.isLogging = false

                if success {
                    // Update hasBeenLogged for the logged food items
                    for index in plate.items.indices {
                        if !plate.items[index].hasBeenLogged {
                            plate.items[index].hasBeenLogged = true
                        }
                    }
                    plate.saveToUserDefaults()
                    self.logAlert = LogAlert(title: "Lyckades", message: "Nya livsmedel har loggats till Apple Hälsa.")
                } else {
                    self.logAlert = LogAlert(title: "Fel", message: "Kunde inte logga till Apple Hälsa.")
                }

                if let error = error {
                    print("Error logging to HealthKit: \(error.localizedDescription)")
                }
            }
        }
    }
}
