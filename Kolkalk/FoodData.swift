// Kolkalk/FoodData_iOS.swift (eller Kolkalk/FoodData.swift)

import SwiftUI
import Foundation
import Combine
import CloudKit // Importera CloudKit

// Samma struktur som Watch-versionen, men med CSV-import
class FoodData_iOS: ObservableObject {
    @Published var foodList: [FoodItem] = []
    private var cancellables = Set<AnyCancellable>()
    private var isSavingCSV = false // Flagga för att undvika dubbla sparanden

    init() {
        print("FoodData [iOS]: init called.") // Se att init körs

        // Lyssna på uppdateringssignaler från CloudKitDataStore
        CloudKitFoodDataStore.shared.foodListNeedsUpdate
            .sink { [weak self] in
                 print("FoodData [iOS]: Received update signal. Fetching...")
                 self?.loadFoodList()
            }
            .store(in: &cancellables)

        // Ladda listan initialt
        print("FoodData [iOS]: Calling loadFoodList from init.")
        loadFoodList()
    }

    // Ladda om listan från CloudKit
    func loadFoodList() {
        print("FoodData [iOS]: loadFoodList called. Fetching from CloudKit...")
        CloudKitFoodDataStore.shared.fetchFoodItems { [weak self] (items, error) in
             // Logga direkt när completion körs, INNAN main queue
            print("FoodData [iOS]: fetchFoodItems completion handler started.")
            if let error = error {
                print("FoodData [iOS]: Error received in loadFoodList completion: \(error)")
                // Töm listan vid fel för att undvika att visa gammal data?
                 DispatchQueue.main.async {
                    self?.foodList = []
                 }
                return
            }

            let receivedCount = items?.count ?? 0
            print("FoodData [iOS]: fetchFoodItems completion successful. Received \(receivedCount) items. Dispatching to main thread...")

            DispatchQueue.main.async {
                guard let self = self else {
                    print("FoodData [iOS]: self is nil in main thread dispatch.")
                    return
                }
                print("FoodData [iOS]: Updating @Published foodList on main thread.")
                self.foodList = items ?? []
                print("FoodData [iOS]: @Published foodList updated. New count: \(self.foodList.count)")
            }
        }
    }

    // Lägg till ett nytt livsmedel via CloudKit
     func addFoodItem(_ foodItem: FoodItem) {
         CloudKitFoodDataStore.shared.saveFoodItem(foodItem) { [weak self] error in
             DispatchQueue.main.async {
                 if let error = error {
                     print("Error adding food item in iOS App: \(error)")
                 } else {
                    if !(self?.foodList.contains(where: { $0.id == foodItem.id }) ?? false) {
                         self?.foodList.append(foodItem)
                         self?.sortFoodList()
                    }
                    print("iOS FoodData added item (locally). CloudKit save initiated.")
                 }
             }
         }
     }

     // Uppdatera ett livsmedel via CloudKit
     func updateFoodItem(_ foodItem: FoodItem) {
          CloudKitFoodDataStore.shared.saveFoodItem(foodItem) { [weak self] error in
              DispatchQueue.main.async {
                  if let error = error {
                      print("Error updating food item in iOS App: \(error)")
                  } else {
                      if let index = self?.foodList.firstIndex(where: { $0.id == foodItem.id }) {
                          self?.foodList[index] = foodItem
                          self?.sortFoodList()
                      }
                      print("iOS FoodData updated item (locally). CloudKit save initiated.")
                  }
              }
          }
      }

     // Radera ett livsmedel via CloudKit
      func deleteFoodItem(withId id: UUID) {
          CloudKitFoodDataStore.shared.deleteFoodItem(withId: id) { [weak self] error in
              DispatchQueue.main.async {
                  if let error = error {
                      print("Error deleting food item in iOS App: \(error)")
                  } else {
                      self?.foodList.removeAll { $0.id == id }
                      print("iOS FoodData deleted item (locally). CloudKit delete initiated.")
                  }
              }
          }
      }

    // Radera alla via CloudKit
     func deleteAllFoodItems() {
        let itemsToDelete = foodList
        guard !itemsToDelete.isEmpty else { return }
        let recordIDsToDelete = itemsToDelete.map { CKRecord.ID(recordName: $0.id.uuidString) }
        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDsToDelete)
        operation.modifyRecordsResultBlock = { [weak self] result in
             DispatchQueue.main.async {
                 switch result {
                 case .success():
                     print("Successfully deleted all food items from CloudKit.")
                     self?.foodList.removeAll()
                 case .failure(let error):
                     print("Error deleting all food items from CloudKit: \(error)")
                     self?.loadFoodList() // Ladda om vid fel
                 }
             }
         }
        CloudKitFoodDataStore.shared.database.add(operation)
     }

    // Importera från CSV-fil och spara till CloudKit
    func importFromCSV(fileURL: URL, completion: @escaping (Result<Int, Error>) -> Void) {
        guard !isSavingCSV else {
             print("Already saving CSV data.")
             completion(.success(0))
             return
         }
         isSavingCSV = true
         print("Starting CSV import...")

        var importedCount = 0
        var itemsToSave: [FoodItem] = []
        let parsingGroup = DispatchGroup()

         parsingGroup.enter()
         DispatchQueue.global(qos: .userInitiated).async {
            defer { parsingGroup.leave() }
             do {
                 let data = try String(contentsOf: fileURL, encoding: .utf8)
                 let rows = data.components(separatedBy: .newlines)
                 print("CSV rows: \(rows.count)")

                 for (index, row) in rows.enumerated() where !row.isEmpty {
                     let columns = row.components(separatedBy: ";")

                     if columns.count >= 2 {
                         let name = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
                         let carbsString = columns[1].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")

                         if let carbsPer100g = Double(carbsString), !name.isEmpty {
                             var gramsPerDl: Double? = nil
                             if columns.count > 2 {
                                 let gramsPerDlString = columns[2].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
                                 if !gramsPerDlString.isEmpty { gramsPerDl = Double(gramsPerDlString) }
                             }
                             var styckPerGram: Double? = nil
                             if columns.count > 3 {
                                 let styckPerGramString = columns[3].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
                                 if !styckPerGramString.isEmpty { styckPerGram = Double(styckPerGramString) }
                             }
                             var isFavorite: Bool = false
                             if columns.count > 4 {
                                 isFavorite = columns[4].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "true"
                             }
                             let newFoodItem = FoodItem(
                                 name: name, carbsPer100g: carbsPer100g, grams: 0,
                                 gramsPerDl: gramsPerDl, styckPerGram: styckPerGram, isFavorite: isFavorite
                             )
                             itemsToSave.append(newFoodItem)
                             importedCount += 1
                         } else {
                             if !(name.isEmpty && carbsString.isEmpty && columns.count <= 2) {
                                 print("Skipping row \(index + 1): Invalid carbs ('\(carbsString)') or empty name ('\(name)')")
                             }
                         }
                     } else if !row.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                         print("Skipping row \(index + 1): Not enough columns (\(columns.count))")
                     }
                 }
             } catch {
                 print("Error reading CSV file: \(error)")
                  DispatchQueue.main.async {
                      self.isSavingCSV = false
                      completion(.failure(error))
                  }
                 return
             }
         }

        parsingGroup.notify(queue: .main) {
            print("CSV parsing complete. Items to save: \(itemsToSave.count)")
             guard !itemsToSave.isEmpty else {
                 print("No valid items found in CSV to save.")
                 self.isSavingCSV = false
                 completion(.success(0))
                 return
             }

             let recordsToSave = itemsToSave.map { $0.toCKRecord() }
             let operation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: nil)
             operation.savePolicy = .allKeys

            var successfullySavedCount = 0
            operation.perRecordSaveBlock = { recordId, result in
                 switch result {
                 case .success(_): successfullySavedCount += 1
                 case .failure(let error): print("Failed to save record \(recordId.recordName): \(error)")
                 }
             }

             operation.modifyRecordsResultBlock = { [weak self] result in
                 DispatchQueue.main.async {
                    self?.isSavingCSV = false
                     switch result {
                     case .success():
                         print("CSV Batch save completed. Successfully saved \(successfullySavedCount) items.")
                         self?.loadFoodList() // Ladda om efter lyckad import
                         completion(.success(successfullySavedCount))
                     case .failure(let error):
                         print("CSV Batch save failed: \(error)")
                         self?.loadFoodList() // Ladda om för att se aktuell status
                         completion(.failure(error))
                     }
                 }
             }
             print("Adding batch save operation to database...")
             CloudKitFoodDataStore.shared.database.add(operation)
         }
    }


    // Exportera foodList till CSV-fil inklusive isFavorite
    func exportToCSV(completion: @escaping (Result<URL, Error>) -> Void) {
        // ... (oförändrad från tidigare version) ...
        let fileName = "kolkalk_livsmedel_\(Date().formatted(.iso8601)).csv"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        var csvString = "Name;CarbsPer100g;GramsPerDl;StyckPerGram;IsFavorite\n"
        let sortedList = foodList.sorted { $0.name.lowercased() < $1.name.lowercased() }
        for food in sortedList {
            let name = food.name.replacingOccurrences(of: ";", with: ",")
            let carbs = food.carbsPer100g != nil ? String(format: "%.1f", food.carbsPer100g!).replacingOccurrences(of: ".", with: ",") : ""
            let gramsPerDl = food.gramsPerDl != nil ? String(format: "%.1f", food.gramsPerDl!).replacingOccurrences(of: ".", with: ",") : ""
            let styckPerGram = food.styckPerGram != nil ? String(format: "%.1f", food.styckPerGram!).replacingOccurrences(of: ".", with: ",") : ""
            let favorite = food.isFavorite ? "true" : "false"
            let row = "\(name);\(carbs);\(gramsPerDl);\(styckPerGram);\(favorite)\n"
            csvString.append(row)
        }
        do {
            try csvString.write(to: path, atomically: true, encoding: .utf8)
            print("CSV-fil exporterad till \(path.path)")
            completion(.success(path))
        } catch {
            print("Fel vid export av CSV-fil: \(error)")
            completion(.failure(error))
        }
    }

    // Sortera lokalt
    private func sortFoodList() {
        foodList.sort { $0.name.lowercased() < $1.name.lowercased() }
    }
}
