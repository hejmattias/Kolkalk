import SwiftUI
import Foundation

// FoodData-klassen som hanterar listan av livsmedel
class FoodData: ObservableObject {
    @Published var foodList: [FoodItem] = []

    init() {
        loadFromUserDefaults()
    }

    // Lägg till ett nytt livsmedel och sortera listan
    func addFoodItem(_ foodItem: FoodItem) {
        foodList.append(foodItem)
        sortFoodList()
        saveToUserDefaults()
    }

    // Spara användarskapade livsmedel till UserDefaults
    func saveToUserDefaults() {
        let userAddedFoods = foodList.filter { $0.isDefault != true }
        if let data = try? JSONEncoder().encode(userAddedFoods) {
            UserDefaults.standard.set(data, forKey: "userFoodList")
        }
    }

    // Ladda livsmedel från UserDefaults och sortera dem
    func loadFromUserDefaults() {
        var updatedFoodList = defaultFoodList
        if let data = UserDefaults.standard.data(forKey: "userFoodList"),
           let savedUserFoods = try? JSONDecoder().decode([FoodItem].self, from: data) {
            updatedFoodList.append(contentsOf: savedUserFoods)
        }
        // Sortera listan i bokstavsordning
        foodList = updatedFoodList.sorted(by: { $0.name.lowercased() < $1.name.lowercased() })
    }

    // Standardlivsmedel
    // Standardlivsmedel
    private var defaultFoodList: [FoodItem] {
        return [
        ]
    }

    // Importera från CSV-fil och sortera listan
    func importFromCSV(fileURL: URL) {
        do {
            // Läs in filens innehåll som en sträng
            let data = try String(contentsOf: fileURL, encoding: .utf8)
            // Dela upp innehållet i rader baserat på ny rad
            let rows = data.components(separatedBy: .newlines)
            
            for (index, row) in rows.enumerated() {
                // Dela upp varje rad i kolumner baserat på semikolon
                let columns = row.components(separatedBy: ";")
                
                // Hoppa över tomma rader
                if columns.count == 1 && columns[0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continue
                }
                
                // Kontrollera att det finns minst två kolumner (namn och kolhydrater)
                if columns.count >= 2 {
                    let name = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    // Byt ut komma mot punkt för att hantera decimaltal
                    let carbsString = columns[1].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
                    
                    // Försök konvertera kolhydrater per 100g till Double
                    if let carbsPer100g = Double(carbsString) {
                        
                        var gramsPerDl: Double? = nil
                        // Om det finns en tredje kolumn, behandla den som gram per dl
                        if columns.count > 2 {
                            let gramsPerDlString = columns[2].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
                            if !gramsPerDlString.isEmpty, let gramsPerDlValue = Double(gramsPerDlString) {
                                gramsPerDl = gramsPerDlValue
                            }
                        }
                        
                        var styckPerGram: Double? = nil
                        // Om det finns en fjärde kolumn, behandla den som gram per styck
                        if columns.count > 3 {
                            let styckPerGramString = columns[3].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
                            if !styckPerGramString.isEmpty, let styckPerGramValue = Double(styckPerGramString) {
                                styckPerGram = styckPerGramValue
                            }
                        }
                        
                        // Kontrollera om det finns en femte kolumn för isFavorite
                        var isFavorite: Bool = false
                        if columns.count > 4 {
                            let isFavoriteString = columns[4].trimmingCharacters(in: .whitespacesAndNewlines)
                            isFavorite = isFavoriteString.lowercased() == "true"
                        }
                        
                        // Skapa en ny FoodItem med de importerade värdena
                        let newFoodItem = FoodItem(
                            name: name,
                            carbsPer100g: carbsPer100g,
                            grams: 0,
                            gramsPerDl: gramsPerDl,
                            styckPerGram: styckPerGram,
                            isFavorite: isFavorite
                        )
                        self.foodList.append(newFoodItem)
                        
                    } else {
                        print("Felaktigt värde för kolhydrater per 100g på rad \(index + 1)")
                    }
                } else {
                    print("Felaktig formatering på rad \(index + 1)")
                }
            }
            
            // Sortera listan efter import
            self.sortFoodList()
            self.saveToUserDefaults()
            
        } catch {
            print("Fel vid inläsning av CSV-fil: \(error)")
        }
    }
    
    // Exportera foodList till CSV-fil inklusive isFavorite
    func exportToCSV(fileURL: URL) {
        var csvString = "name,carbsPer100g,gramsPerDl,styckPerGram,isFavorite\n"
        
        // Filtrera ut standardlivsmedel
        let userAddedFoods = foodList.filter { $0.isDefault != true }
        
        for food in userAddedFoods {
            let name = food.name.replacingOccurrences(of: ",", with: ";") // Undvik kommatecken i namn
            let carbs = food.carbsPer100g != nil ? "\(food.carbsPer100g!)" : ""
            let gramsPerDl = food.gramsPerDl != nil ? "\(food.gramsPerDl!)" : ""
            let styckPerGram = food.styckPerGram != nil ? "\(food.styckPerGram!)" : ""
            let favorite = food.isFavorite ? "true" : "false"
            
            let row = "\(name),\(carbs),\(gramsPerDl),\(styckPerGram),\(favorite)\n"
            csvString.append(row)
        }
        
        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            print("CSV-fil exporterad till \(fileURL.path)")
        } catch {
            print("Fel vid export av CSV-fil: \(error)")
        }
    }

    
    // Funktion för att sortera foodList i bokstavsordning
    private func sortFoodList() {
        foodList.sort { $0.name.lowercased() < $1.name.lowercased() }
    }
}

