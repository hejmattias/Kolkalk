// Kolkalk.zip/kolkalk Watch App/PlateView.swift

import SwiftUI
import HealthKit

struct PlateView: View {
    @ObservedObject var plate: Plate
    @Binding var navigationPath: NavigationPath
    // State private var showDetailsForItemId: UUID? // BORTTAGEN

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
                    HStack {
                        // Länk för att redigera (om inte kalkylator)
                        if item.isCalculatorItem {
                            // Gör kalkylator-rader icke-klickbara för redigering
                            HStack {
                                Text(item.name)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                if item.hasBeenLogged && enableCarbLogging {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        } else {
                            // Länk för vanliga livsmedel
                            NavigationLink(value: Route.editPlateItem(item)) {
                                HStack {
                                    Text(item.name)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    if item.hasBeenLogged && enableCarbLogging {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        }
                        Spacer()
                        Text("\(item.totalCarbs, specifier: "%.1f") gk")
                    }

                    // *** ÄNDRING: Visa alltid detaljer ***
                    Text(itemDetailString(for: item))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 1) // Lite extra luft
                    // *** SLUT ÄNDRING ***
                }
                .contentShape(Rectangle())
                // .gesture(...) // BORTTAGEN
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        deleteItem(item: item)
                    } label: {
                        Label("Ta bort", systemImage: "trash")
                    }
                }
                // Låt swipe-edit finnas kvar även om klick-edit tas bort för kalkylator
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

                // *** NY PLATS FÖR "+"-KNAPPEN ***
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
                // *** SLUT NY PLATS ***

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
                // *** LÄGG TILL "+"-KNAPPEN ÄVEN HÄR ***
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
                    .padding(.top) // Lite utrymme från knappen ovan
            }

        } // End List
        .navigationTitle("Totalt: \(totalCarbs, specifier: "%.1f") gk")
        // .toolbar { } // Toolbar borttagen då knappen flyttats
        // .onDisappear { showDetailsForItemId = nil } // BORTTAGEN
        .alert(item: $logAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Helper Methods (deleteItem, itemDetailString, logToHealth) - Oförändrade

    private func deleteItem(item: FoodItem) {
        if let index = plate.items.firstIndex(where: { $0.id == item.id }) {
            plate.items.remove(at: index)
            plate.saveToUserDefaults()
        }
    }

    private func itemDetailString(for item: FoodItem) -> String {
        // Om det är ett kalkylatorobjekt, visa bara gram
        if item.isCalculatorItem {
            return "\(String(format: "%.1f", item.grams))g (kalkyl)"
        }

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
                // Om gramsPerDl saknas eller är 0, visa bara gram
                return gramsString
            }
        case "st":
            if let styckPerGram = item.styckPerGram, styckPerGram > 0 {
                inputValue = item.grams / styckPerGram
                unitString = "st"
            } else {
                 // Om styckPerGram saknas eller är 0, visa bara gram
                return gramsString
            }
        default:
             // Om okänd enhet, visa bara gram
            return gramsString
        }

        // Om enheten är gram, visa bara det
        if unitString == "g" {
            return "\(String(format: "%.1f", inputValue))\(unitString)"
        } else {
            // Annars, visa t.ex. "1.5dl (150g)"
            return "\(String(format: "%.1f", inputValue))\(unitString) (\(gramsString))"
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
            // Anpassa metadata baserat på om det är kalkylator eller vanligt
            if item.isCalculatorItem {
                return "\(item.name): \(String(format: "%.1f", item.grams))g" // Visa uträkning och resultat i gram
            } else {
                 return "\(item.name): \(item.formattedDetail())" // Använd befintlig formatering
            }
        }.joined(separator: "; ")

        let metadata = [
            HKMetadataKeyFoodType: foodDetails
        ]

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
