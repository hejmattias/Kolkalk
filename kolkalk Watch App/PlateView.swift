// Kolkalk/kolkalk Watch App/PlateView.swift

import SwiftUI
import HealthKit

struct PlateView: View {
    @ObservedObject var plate: Plate
    @Binding var navigationPath: NavigationPath

    @State private var isLogging = false
    @State private var logAlert: LogAlert?

    @AppStorage("enableCarbLogging") private var enableCarbLogging = true
    @AppStorage("enableInsulinLogging") private var enableInsulinLogging = true

    var totalCarbs: Double {
        plate.items.reduce(0) { $0 + $1.totalCarbs }
    }

    struct LogAlert: Identifiable {
        var id = UUID()
        var title: String
        var message: String
    }

    var body: some View {
        List {
            // MARK: - List Items
            ForEach(plate.items) { item in
                VStack(alignment: .leading) {
                    // Huvudraden med Länk och kolhydratsvärde
                    HStack {
                        NavigationLink(value: Route.editPlateItem(item)) {
                            HStack { // Innehållet för länken
                                if item.isCalculatorItem {
                                    Text("Kalkylator")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                } else {
                                    Text(item.name)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                }
                                if item.hasBeenLogged && enableCarbLogging {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Spacer()
                        Text("\(item.totalCarbs, specifier: "%.1f") gk") // Kolhydratvärdet (oförändrat)
                    }

                    // Grå informationsrad under huvudraden
                    Text(itemDetailString(for: item)) // Använder hjälpfunktionen nedan
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 1)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        deleteItem(item: item)
                    } label: {
                        Label("Ta bort", systemImage: "trash")
                    }
                }
                 .swipeActions(edge: .leading) {
                     Button {
                         navigationPath.append(Route.editPlateItem(item)) // Navigera till redigering
                     } label: {
                         Label("Redigera", systemImage: "pencil")
                     }
                     .tint(.blue)
                 }
            } // End ForEach

            // MARK: - Buttons Below Items
            if !plate.items.isEmpty {
                // Knappar när tallriken INTE är tom (oförändrade)
                Button { navigationPath.append(Route.foodListView(isEmptyAndAdd: false)) } label: {
                    HStack { Spacer(); Label("Lägg till", systemImage: "plus").foregroundColor(.blue); Spacer() }
                }
                Button(action: {
                    navigationPath.append(Route.foodListView(isEmptyAndAdd: true))
                }) {
                    HStack { Spacer(); Label("Töm & Lägg till", systemImage: "trash.circle").foregroundColor(.blue); Spacer() }
                }

                if enableCarbLogging {
                    Button(action: { logToHealth() }) {
                        HStack { Spacer(); Text("Logga kolhydrater").foregroundColor(.blue); Spacer() }
                    }
                    .disabled(isLogging || plate.items.allSatisfy { $0.hasBeenLogged })
                }
                if enableInsulinLogging {
                     Button(action: { navigationPath.append(Route.insulinLoggingView) }) {
                         HStack { Spacer(); Text("Logga insulin").foregroundColor(.blue); Spacer() }
                     }
                 }
            } else {
                // Knappar när tallriken ÄR tom (oförändrade)
                Button { navigationPath.append(Route.foodListView(isEmptyAndAdd: false)) } label: {
                     HStack { Spacer(); Label("Lägg till", systemImage: "plus").foregroundColor(.blue); Spacer() }
                 }
                if enableInsulinLogging {
                     Button(action: { navigationPath.append(Route.insulinLoggingView) }) {
                         HStack { Spacer(); Text("Logga insulin").foregroundColor(.blue); Spacer() }
                     }
                 }

                 // <<< ÄNDRING START: Centrera texten i egen sektion >>>
                 Section { // Lägg texten i en egen sektion
                      HStack { // Använd HStack för att centrera horisontellt
                          Spacer()
                          Text("Tallriken är tom.")
                              .foregroundColor(.gray)
                          Spacer()
                      }
                      .listRowBackground(Color.clear) // Gör radbakgrunden osynlig
                  }
                  // <<< ÄNDRING SLUT >>>
            }
        } // End List
        .navigationTitle("Totalt: \(totalCarbs, specifier: "%.1f") gk")
        .alert(item: $logAlert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
    }

    // MARK: - Helper Methods (Oförändrade)
    private func deleteItem(item: FoodItem) {
        if let index = plate.items.firstIndex(where: { $0.id == item.id }) {
            plate.items.remove(at: index)
            plate.saveToUserDefaults()
        }
    }

    private func itemDetailString(for item: FoodItem) -> String {
        if item.isCalculatorItem { return item.name }

        let gramsString = "\(String(format: "%.1f", item.grams))g"
        guard let inputUnit = item.inputUnit else { return gramsString }

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
            } else { return gramsString }
        case "st":
            if let styckPerGram = item.styckPerGram, styckPerGram > 0 {
                inputValue = item.grams / styckPerGram
                unitString = "st"
            } else { return gramsString }
        default:
            return gramsString
        }

        let formattedInputValue = String(format: "%.2f", inputValue)

        if unitString == "g" {
             return "\(formattedInputValue)\(unitString)"
        } else {
            return "\(formattedInputValue)\(unitString) (\(gramsString))"
        }
    }

    private func logToHealth() {
        isLogging = true
        let itemsToLog = plate.items.filter { !$0.hasBeenLogged }
        guard !itemsToLog.isEmpty else {
            isLogging = false
            self.logAlert = LogAlert(title: "Inget att logga", message: "Det finns inga nya livsmedel att logga.")
            return
        }
        let totalCarbsToLog = itemsToLog.reduce(0) { $0 + $1.totalCarbs }
        let foodDetails = itemsToLog.map { item in
            if item.isCalculatorItem {
                 return "\(item.name)=\(String(format: "%.1f", item.totalCarbs))gk"
            } else {
                 return "\(item.name): \(item.formattedDetail())"
            }
        }.joined(separator: "; ")
        let metadata = [ HKMetadataKeyFoodType: foodDetails ]

        HealthKitManager.shared.logCarbohydrates(totalCarbs: totalCarbsToLog, metadata: metadata) { success, error in
            DispatchQueue.main.async {
                self.isLogging = false
                if success {
                    for index in self.plate.items.indices {
                        if itemsToLog.contains(where: { $0.id == self.plate.items[index].id }) {
                            self.plate.items[index].hasBeenLogged = true
                        }
                    }
                    self.plate.saveToUserDefaults()
                    self.logAlert = LogAlert(title: "Lyckades", message: "Kolhydrater har loggats till Apple Hälsa.")
                } else {
                    self.logAlert = LogAlert(title: "Fel", message: "Kunde inte logga kolhydrater till Apple Hälsa.")
                }
                if let error = error {
                    print("Error logging to HealthKit: \(error.localizedDescription)")
                }
            }
        }
    }
}
