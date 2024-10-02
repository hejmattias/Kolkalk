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
    private var defaultFoodList: [FoodItem] {
        return [
            FoodItem(name: "Äpple", carbsPer100g: 11.4, grams: 0, gramsPerDl: 65, isDefault: true),
            FoodItem(name: "Fiskpinnar", carbsPer100g: 10, grams: 0, gramsPerDl: 50, styckPerGram: 100, isDefault: true),
            FoodItem(name: "Pinnfiskar", carbsPer100g: 10, grams: 0, styckPerGram: 100, isDefault: true),
            FoodItem(name: "Banan", carbsPer100g: 22.8, grams: 0, gramsPerDl: 85, isDefault: true)
        ]
    }

    // Importera från CSV-fil och sortera listan
    func importFromCSV(fileURL: URL) {
        do {
            let data = try String(contentsOf: fileURL, encoding: .utf8)
            let rows = data.components(separatedBy: .newlines)
            
            for (index, row) in rows.enumerated() {
                let columns = row.components(separatedBy: ",")
                
                // Hoppa över tomma rader
                if columns.count == 1 && columns[0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continue
                }
                
                if columns.count >= 2 {
                    let name = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let carbsString = columns[1].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
                    
                    if let carbsPer100g = Double(carbsString) {
                        
                        var gramsPerDl: Double? = nil
                        if columns.count > 2 {
                            let gramsPerDlString = columns[2].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
                            if !gramsPerDlString.isEmpty, let gramsPerDlValue = Double(gramsPerDlString) {
                                gramsPerDl = gramsPerDlValue
                            }
                        }
                        
                        var styckPerGram: Double? = nil
                        if columns.count > 3 {
                            let styckPerGramString = columns[3].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
                            if !styckPerGramString.isEmpty, let styckPerGramValue = Double(styckPerGramString) {
                                styckPerGram = styckPerGramValue
                            }
                        }
                        
                        let newFoodItem = FoodItem(name: name, carbsPer100g: carbsPer100g, grams: 0, gramsPerDl: gramsPerDl, styckPerGram: styckPerGram)
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
    
    // Sortera foodList i bokstavsordning
    private func sortFoodList() {
        foodList.sort { $0.name.lowercased() < $1.name.lowercased() }
    }
}
