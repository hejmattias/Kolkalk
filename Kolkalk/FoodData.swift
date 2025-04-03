// Kolkalk/FoodData.swift (innehåller klassen FoodData_iOS)

import SwiftUI
import Foundation
import Combine
import CloudKit

class FoodData_iOS: ObservableObject {
    @Published var foodList: [FoodItem] = []
    @Published var isLoading: Bool = true
    @Published var lastSyncTime: Date? = nil
    @Published var lastSyncError: Error? = nil
    private var cancellables = Set<AnyCancellable>()
    private var isSavingCSV = false

    // localCacheURL och init (oförändrade)
    private var localCacheURL: URL? {
        guard let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("FoodData_iOS Error: Could not find Application Support directory.")
            return nil
        }
        let subDirectory = appSupportDirectory.appendingPathComponent("DataCache")
        do {
            try FileManager.default.createDirectory(at: subDirectory, withIntermediateDirectories: true, attributes: nil)
            return subDirectory.appendingPathComponent("foodListCache_iOS.json")
        } catch {
            print("FoodData_iOS Error: Could not create cache subdirectory: \(error)")
            return nil
        }
    }

    init() {
        print("FoodData [iOS]: init called.")
        if loadFoodListLocally() {
            print("FoodData [iOS]: Successfully loaded from local cache.")
            self.isLoading = false
        } else {
            print("FoodData [iOS]: Local cache empty or failed to load.")
        }

        CloudKitFoodDataStore.shared.foodListNeedsUpdate
            .sink { [weak self] in
                print("FoodData [iOS]: Received CloudKit update signal. Fetching...")
                self?.loadFoodListFromCloudKit()
            }
            .store(in: &cancellables)

        print("FoodData [iOS]: Initiating background CloudKit fetch from init.")
        loadFoodListFromCloudKit()
    }

    // loadFoodListLocally och saveFoodListLocally (oförändrade)
    private func loadFoodListLocally() -> Bool {
        guard let url = localCacheURL else { return false }
        print("FoodData [iOS]: Attempting to load cache from: \(url.path)")
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("FoodData [iOS]: Cache file does not exist.")
            return false
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let cachedList = try decoder.decode([FoodItem].self, from: data)
            let sortedList = cachedList.sorted { $0.name.lowercased() < $1.name.lowercased() }
            DispatchQueue.main.async {
                self.foodList = sortedList
                print("FoodData [iOS]: Successfully loaded \(self.foodList.count) items from cache.")
            }
            return true
        } catch {
            print("FoodData [iOS]: Error loading or decoding local cache: \(error)")
            try? FileManager.default.removeItem(at: url)
            return false
        }
    }

    private func saveFoodListLocally() {
        guard let url = localCacheURL else { return }
        let listToSave = self.foodList
        print("FoodData [iOS]: Attempting to save \(listToSave.count) items to cache: \(url.path)")

        DispatchQueue.global(qos: .background).async {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(listToSave)
                try data.write(to: url, options: [.atomic])
                print("FoodData [iOS]: Successfully saved cache.")
            } catch {
                print("FoodData [iOS]: Error encoding or saving local cache: \(error)")
            }
        }
    }

    // loadFoodListFromCloudKit (oförändrad - sätter lastSyncTime vid lyckad HÄMTNING)
    func loadFoodListFromCloudKit() {
         DispatchQueue.main.async {
             if !self.isLoading {
                 print("FoodData [iOS]: Setting isLoading = true.")
                 self.isLoading = true
             }
             self.lastSyncError = nil
         }
        print("FoodData [iOS]: loadFoodListFromCloudKit called.")

        CloudKitFoodDataStore.shared.fetchFoodItems { [weak self] (items, error) in
            guard let self = self else { return }
            print("FoodData [iOS]: CloudKit fetch completion handler started.")

            DispatchQueue.main.async {
                 print("FoodData [iOS]: Setting isLoading = false.")
                 self.isLoading = false

                 if let error = error {
                     print("FoodData [iOS]: Error fetching from CloudKit: \(error)")
                     self.lastSyncError = error // Spara felet
                     return
                 }

                 // *** Sätter tiden vid lyckad HÄMTNING ***
                 self.lastSyncError = nil
                 self.lastSyncTime = Date()

                 let receivedItems = items ?? []
                 print("FoodData [iOS]: CloudKit fetch successful. Received \(receivedItems.count) items.")
                 let sortedReceivedItems = receivedItems.sorted { $0.name.lowercased() < $1.name.lowercased() }

                 if self.foodList != sortedReceivedItems {
                     print("FoodData [iOS]: CloudKit data differs. Updating UI and saving cache.")
                     self.foodList = sortedReceivedItems
                     self.saveFoodListLocally()
                 } else {
                    print("FoodData [iOS]: CloudKit data same as local. No UI update needed.")
                 }
             }
        }
    }

    // --- CRUD Operations (Med uppdaterad lastSyncTime) ---

    func addFoodItem(_ foodItem: FoodItem) {
        // Optimistisk UI-uppdatering (oförändrad)
        DispatchQueue.main.async {
             if !self.foodList.contains(where: { $0.id == foodItem.id }) {
                 self.foodList.append(foodItem)
                 self.sortFoodList()
                 self.saveFoodListLocally()
                 print("FoodData [iOS]: Added item locally & saved cache. ID: \(foodItem.id)")
             } else {
                 print("FoodData [iOS]: Add aborted, item with ID \(foodItem.id) already exists locally.")
                 return
             }
        }

        // Skicka till CloudKit
        CloudKitFoodDataStore.shared.saveFoodItem(foodItem) { [weak self] error in
            // *** ÄNDRING: Uppdatera lastSyncTime vid lyckad save ***
            DispatchQueue.main.async { // Säkerställ att vi är på main thread för @Published
                 guard let self = self else { return }
                 if let error = error {
                     print("FoodData Error: CK save failed (add) ID \(foodItem.id): \(error)")
                     self.lastSyncError = error // Sätt error-flagga
                     // Överväg felhantering
                 } else {
                     print("FoodData [iOS]: CK save success (add) ID \(foodItem.id)")
                     self.lastSyncTime = Date() // Sätt tiden vid lyckad SPARA
                     self.lastSyncError = nil // Nollställ eventuellt tidigare fel
                 }
             }
            // *** SLUT ÄNDRING ***
        }
    }

    func updateFoodItem(_ foodItem: FoodItem) {
        // Optimistisk UI-uppdatering (oförändrad)
        DispatchQueue.main.async {
            if let index = self.foodList.firstIndex(where: { $0.id == foodItem.id }) {
                self.foodList[index] = foodItem
                self.sortFoodList()
                self.saveFoodListLocally()
                print("FoodData [iOS]: Updated item locally & saved cache. ID: \(foodItem.id)")
            } else {
                print("FoodData [iOS]: Update aborted, item with ID \(foodItem.id) not found locally.")
                return
            }
        }

        // Skicka till CloudKit
        CloudKitFoodDataStore.shared.saveFoodItem(foodItem) { [weak self] error in
             // *** ÄNDRING: Uppdatera lastSyncTime vid lyckad save ***
             DispatchQueue.main.async { // Säkerställ att vi är på main thread för @Published
                 guard let self = self else { return }
                 if let error = error {
                     print("FoodData Error: CK save failed (update) ID \(foodItem.id): \(error)")
                     self.lastSyncError = error // Sätt error-flagga
                     // Överväg felhantering
                 } else {
                     print("FoodData [iOS]: CK save success (update) ID \(foodItem.id)")
                     self.lastSyncTime = Date() // Sätt tiden vid lyckad SPARA/UPPDATERA
                     self.lastSyncError = nil // Nollställ eventuellt tidigare fel
                 }
             }
             // *** SLUT ÄNDRING ***
        }
    }

    // toggleFavoriteStatus (oförändrad, anropar updateFoodItem som nu sätter tiden)
    func toggleFavoriteStatus(for foodItem: FoodItem) {
        var updatedFoodItem = foodItem
        updatedFoodItem.isFavorite.toggle()
        updateFoodItem(updatedFoodItem) // updateFoodItem hanterar nu tidsuppdateringen
        print("FoodData [iOS]: Toggled favorite status for \(foodItem.name) to \(updatedFoodItem.isFavorite)")
    }

    func deleteFoodItem(withId id: UUID) {
        // Optimistisk UI-uppdatering (oförändrad)
        DispatchQueue.main.async {
            let originalCount = self.foodList.count
            self.foodList.removeAll { $0.id == id }
            if self.foodList.count < originalCount {
                self.saveFoodListLocally()
                print("FoodData [iOS]: Deleted item locally & saved cache. ID: \(id)")
            } else {
                print("FoodData [iOS]: Delete aborted, item with ID \(id) not found locally.")
                return
            }
        }

        // Skicka till CloudKit
        CloudKitFoodDataStore.shared.deleteFoodItem(withId: id) { [weak self] error in
             // *** ÄNDRING: Uppdatera lastSyncTime vid lyckad delete ***
             DispatchQueue.main.async { // Säkerställ att vi är på main thread för @Published
                 guard let self = self else { return }
                 if let error = error {
                     print("FoodData Error: CK delete failed ID \(id): \(error)")
                     self.lastSyncError = error // Sätt error-flagga
                     // Ladda om listan för att synkronisera med servern vid fel?
                     self.loadFoodListFromCloudKit()
                 } else {
                     print("FoodData [iOS]: CK delete success ID \(id)")
                     self.lastSyncTime = Date() // Sätt tiden vid lyckad RADERING
                     self.lastSyncError = nil // Nollställ eventuellt tidigare fel
                 }
             }
             // *** SLUT ÄNDRING ***
        }
    }

    func deleteAllFoodItems() {
        let itemsToDelete = self.foodList
        guard !itemsToDelete.isEmpty else {
            print("FoodData [iOS]: deleteAllFoodItems called, but list is already empty.");
            return
        }
        let recordIDsToDelete = itemsToDelete.map { CKRecord.ID(recordName: $0.id.uuidString) }

        // Optimistisk UI-uppdatering (oförändrad)
        DispatchQueue.main.async {
            self.foodList.removeAll()
            self.saveFoodListLocally()
            print("FoodData [iOS]: Deleted all items locally & saved cache.")
        }

        // Använd CloudKitDataStore för att radera (förutsätter att funktionen finns där)
        // Justerar anropet för att matcha den funktion vi skapade i CloudKitFoodDataStore
        CloudKitFoodDataStore.shared.deleteAllFoodItems(recordIDsToDelete: recordIDsToDelete) { [weak self] error in
            // *** ÄNDRING: Uppdatera lastSyncTime vid lyckad deleteAll ***
            DispatchQueue.main.async { // Säkerställ att vi är på main thread för @Published
                guard let self = self else { return }
                if let error = error {
                    print("FoodData Error: Failed to delete all items from CloudKit: \(error)")
                    self.lastSyncError = error // Sätt error-flagga
                    // Ladda om från CloudKit för att återställa till serverns status
                    self.loadFoodListFromCloudKit()
                } else {
                     print("FoodData [iOS]: Successfully deleted all items from CloudKit via deleteAllFoodItems.")
                     self.lastSyncTime = Date() // Sätt tiden vid lyckad RADERING AV ALLA
                     self.lastSyncError = nil // Nollställ eventuellt tidigare fel
                 }
            }
            // *** SLUT ÄNDRING ***
        }
    }


    // --- CSV Import/Export (oförändrade) ---

    func importFromCSV(fileURL: URL, completion: @escaping (Result<Int, Error>) -> Void) {
        guard !isSavingCSV else {
            print("FoodData [iOS]: Import already in progress.")
            completion(.success(0))
            return
        }
        isSavingCSV = true
        print("FoodData [iOS]: Starting CSV import from \(fileURL.lastPathComponent)...")
        var parsedItemsFromCSV: [FoodItem] = []
        var parsingError: Error? = nil
        let parsingGroup = DispatchGroup()
        parsingGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            defer { parsingGroup.leave() }
            do {
                let data = try String(contentsOf: fileURL, encoding: .utf8)
                let rows = data.components(separatedBy: .newlines)
                print("FoodData [iOS]: CSV rows found: \(rows.count)")
                for (index, row) in rows.enumerated() where !row.isEmpty {
                    let columns = row.components(separatedBy: ";")
                    let trimmedColumns = columns.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
                    if trimmedColumns.count >= 2 {
                        let name = trimmedColumns[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        let carbsString = trimmedColumns[1].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
                        if let carbsPer100g = Double(carbsString), !name.isEmpty {
                            var gramsPerDl: Double? = nil
                            if trimmedColumns.count > 2 { let gPDS = trimmedColumns[2].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "."); if !gPDS.isEmpty { gramsPerDl = Double(gPDS) } }
                            var styckPerGram: Double? = nil
                            if trimmedColumns.count > 3 { let sPGS = trimmedColumns[3].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "."); if !sPGS.isEmpty { styckPerGram = Double(sPGS) } }
                            var isFavorite: Bool = false
                            if trimmedColumns.count > 4 { isFavorite = trimmedColumns[4].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "true" }
                            let newFoodItem = FoodItem(name: name, carbsPer100g: carbsPer100g, grams: 0, gramsPerDl: gramsPerDl, styckPerGram: styckPerGram, isFavorite: isFavorite)
                            parsedItemsFromCSV.append(newFoodItem)
                        } else { if !(name.isEmpty && carbsString.isEmpty && trimmedColumns.count <= 2) { print("FoodData [iOS]: Skipping CSV row \(index + 1) during parse: Invalid carbs ('\(carbsString)') or empty name ('\(name)')") } }
                    } else if !row.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { print("FoodData [iOS]: Skipping CSV row \(index + 1) during parse: Not enough columns (\(trimmedColumns.count))") }
                }
            } catch { print("FoodData [iOS]: Error reading CSV file: \(error)"); parsingError = error }
        }
        parsingGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { completion(.failure(NSError(domain: "FoodData", code: -2, userInfo: [NSLocalizedDescriptionKey: "Self was deallocated"]))); return }
            if let error = parsingError { self.isSavingCSV = false; completion(.failure(error)); return }
            print("FoodData [iOS]: CSV parsing complete. Parsed \(parsedItemsFromCSV.count) potential items.")
            let currentExistingItemNames = Set(self.foodList.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
            print("FoodData [iOS]: Checking against \(currentExistingItemNames.count) current item names.")
            var itemsToSave: [FoodItem] = []
            var skippedCount = 0
            for item in parsedItemsFromCSV {
                let trimmedLowercasedName = item.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if currentExistingItemNames.contains(trimmedLowercasedName) { skippedCount += 1 } else { itemsToSave.append(item) }
            }
            print("FoodData [iOS]: Filtering complete. Items to save: \(itemsToSave.count). Duplicates skipped: \(skippedCount).")
            guard !itemsToSave.isEmpty else { print("FoodData [iOS]: No valid new items found in CSV to save."); self.isSavingCSV = false; completion(.success(0)); return }
            let recordsToSave = itemsToSave.map { $0.toCKRecord() }
            let operation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: nil)
            operation.savePolicy = .allKeys
            var successfullySavedCount = 0
            operation.perRecordSaveBlock = { recordId, result in switch result { case .success(_): successfullySavedCount += 1; case .failure(let error): print("Failed to save record \(recordId.recordName): \(error)") } }
            operation.modifyRecordsResultBlock = { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.isSavingCSV = false
                    switch result {
                    case .success():
                        print("FoodData [iOS]: CSV Batch save completed. Successfully saved \(successfullySavedCount) of \(itemsToSave.count) new items.")
                        // Uppdatera tiden och ladda om efter lyckad import-batch
                        self.lastSyncTime = Date()
                        self.lastSyncError = nil
                        self.loadFoodListFromCloudKit()
                        completion(.success(successfullySavedCount))
                    case .failure(let error):
                        print("FoodData [iOS]: CSV Batch save failed: \(error)")
                        self.lastSyncError = error // Sätt felet
                        self.loadFoodListFromCloudKit() // Ladda om ändå för att få serverns status
                        completion(.failure(error))
                    }
                }
            }
            print("FoodData [iOS]: Adding CSV batch save operation to CloudKit database...")
            CloudKitFoodDataStore.shared.database.add(operation)
        }
    }


    func exportToCSV(completion: @escaping (Result<URL, Error>) -> Void) {
        let listToExport = self.foodList
        print("FoodData [iOS]: Starting CSV export for \(listToExport.count) items...")
        DispatchQueue.global(qos: .userInitiated).async {
            let dateFormatter = ISO8601DateFormatter(); dateFormatter.formatOptions = [.withInternetDateTime]; let timestamp = dateFormatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let fileName = "kolkalk_livsmedel_\(timestamp).csv"; let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            var csvString = "Name;CarbsPer100g;GramsPerDl;StyckPerGram;IsFavorite\n"
            let sortedList = listToExport.sorted { $0.name.lowercased() < $1.name.lowercased() }
            for food in sortedList {
                let name = "\"\(food.name.replacingOccurrences(of: "\"", with: "\"\""))\""
                let carbs = food.carbsPer100g != nil ? String(format: "%.1f", food.carbsPer100g!).replacingOccurrences(of: ".", with: ",") : ""
                let gramsPerDl = food.gramsPerDl != nil ? String(format: "%.1f", food.gramsPerDl!).replacingOccurrences(of: ".", with: ",") : ""
                let styckPerGram = food.styckPerGram != nil ? String(format: "%.1f", food.styckPerGram!).replacingOccurrences(of: ".", with: ",") : ""
                let favorite = food.isFavorite ? "true" : "false"
                let row = "\(name);\(carbs);\(gramsPerDl);\(styckPerGram);\(favorite)\n"; csvString.append(row)
            }
            do {
                try csvString.write(to: path, atomically: true, encoding: .utf8)
                print("FoodData [iOS]: CSV file successfully exported to \(path.path)")
                DispatchQueue.main.async { completion(.success(path)) }
            } catch {
                print("FoodData [iOS]: Error writing CSV file: \(error)")
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }


    // --- Helper ---

    private func sortFoodList() {
        DispatchQueue.main.async {
            self.foodList.sort { $0.name.lowercased() < $1.name.lowercased() }
        }
    }
}
