// Kolkalk.zip/kolkalk Watch App/PlateView.swift

import SwiftUI
import HealthKit

struct PlateView: View {
    @ObservedObject var plate: Plate
    @Binding var navigationPath: NavigationPath

    @State private var isLogging = false
    @State private var logAlert: LogAlert?
    @State private var showEmptyConfirmation = false

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
                            HStack { // Innehållet för länken (det som visas till vänster)
                                // *** ÄNDRING 1: Visa "Kalkylator" eller livsmedelsnamn ***
                                if item.isCalculatorItem {
                                    Text("Kalkylator") // Visa "Kalkylator"
                                        .font(.body)
                                        .foregroundColor(.primary)
                                } else {
                                    Text(item.name) // Visa vanliga namnet
                                        .font(.body)
                                        .foregroundColor(.primary)
                                }
                                // *** SLUT ÄNDRING 1 ***

                                // Checkmark (oförändrad)
                                if item.hasBeenLogged && enableCarbLogging {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .contentShape(Rectangle()) // Gör textytan klickbar
                        }
                        .buttonStyle(.plain) // Undvik att texten blir blå

                        Spacer() // Flyttar kolhydratvärdet till höger
                        Text("\(item.totalCarbs, specifier: "%.1f") gk") // Kolhydratvärdet (oförändrat)
                    }

                    // Grå informationsrad under huvudraden
                    Text(itemDetailString(for: item)) // Använder hjälpfunktionen nedan
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 1) // Lite extra luft
                }
                // Swipe actions (oförändrade)
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

            // MARK: - Buttons Below Items (Oförändrad sektion)
            if !plate.items.isEmpty {
                // "+"-KNAPPEN
                Button {
                    navigationPath.append(Route.foodListView(isEmptyAndAdd: false))
                } label: {
                    HStack {
                        Spacer()
                        Label("Lägg till", systemImage: "plus")
                             .foregroundColor(.blue)
                        Spacer()
                    }
                }

                // "Töm tallriken" button
                Button(action: {
                    showEmptyConfirmation = true
                }) {
                    HStack {
                        Spacer()
                        Text("Töm tallriken")
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
                .alert("Bekräfta Töm Tallriken", isPresented: $showEmptyConfirmation) {
                    Button("Ja", role: .destructive) { plate.emptyPlate() }
                    Button("Avbryt", role: .cancel) { }
                } message: { Text("Är du säker på att du vill tömma tallriken?") }

                // "Logga kolhydrater" button
                if enableCarbLogging {
                    Button(action: { logToHealth() }) {
                        HStack {
                            Spacer()
                            Text("Logga kolhydrater")
                                .foregroundColor(.blue)
                            Spacer()
                        }
                    }
                    .disabled(isLogging || plate.items.allSatisfy { $0.hasBeenLogged })
                }

                // "Logga insulin" button
                 if enableInsulinLogging {
                     Button(action: {
                         navigationPath.append(Route.insulinLoggingView)
                     }) {
                         HStack {
                             Spacer()
                             Text("Logga insulin")
                                 .foregroundColor(.blue)
                             Spacer()
                         }
                     }
                 }

            } else {
                // Meddelande när tallriken är tom
                Button {
                     navigationPath.append(Route.foodListView(isEmptyAndAdd: false))
                 } label: {
                     HStack {
                         Spacer()
                         Label("Lägg till", systemImage: "plus")
                              .foregroundColor(.blue)
                         Spacer()
                     }
                 }
                Text("Tallriken är tom.")
                    .foregroundColor(.gray)
                    .padding(.top)
            }

        } // End List
        .navigationTitle("Totalt: \(totalCarbs, specifier: "%.1f") gk")
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

    // *** ÄNDRING 2: Justerad itemDetailString ***
    private func itemDetailString(for item: FoodItem) -> String {
        // Om det är ett kalkylatorobjekt, visa bara uträkningen (som finns i item.name)
        if item.isCalculatorItem {
            return item.name // Returnera uträkningen
        }
        // *** SLUT ÄNDRING 2 ***

        // Logik för vanliga livsmedel (oförändrad)
        let gramsString = "\(String(format: "%.1f", item.grams))g"

        guard let inputUnit = item.inputUnit else {
            return gramsString // Fallback om enhet saknas
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

    // logToHealth (oförändrad från förra steget)
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
