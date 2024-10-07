import Foundation
import SwiftUI

struct PlateView: View {
    @ObservedObject var plate: Plate
    @Binding var navigationPath: NavigationPath
    @State private var showDetailsForItemId: UUID?

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

                    // Visa detaljer om användaren sveper
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
                                // Svep från vänster till höger för att visa informationen
                                showDetailsForItemId = item.id
                            } else if value.translation.width < 0 {
                                // Svep från höger till vänster för att dölja informationen
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
                    plate.emptyPlate()
                }) {
                    HStack {
                        Spacer()
                        Text("Töm tallriken")
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Totalt: \(totalCarbs, specifier: "%.1f") Gk")
        .onDisappear {
            showDetailsForItemId = nil
        }
    }
}

// Extension för hjälpfunktioner
extension PlateView {
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

}

