// Kolkalk/FoodData.swift (innehåller klassen FoodData_iOS)

import SwiftUI
import Foundation
import Combine
import CloudKit // Importera CloudKit

// Klassen som hanterar livsmedelsdata för iOS med lokal cache och CloudKit-synk
class FoodData_iOS: ObservableObject {
    // Publicerade variabler för UI-bindning
    @Published var foodList: [FoodItem] = []
    // Visar om en CloudKit-operation pågår (för feedback)
    @Published var isLoading: Bool = true
    private var cancellables = Set<AnyCancellable>() // För Combine
    private var isSavingCSV = false // Flagga för att undvika dubbla CSV-sparanden

    // URL till den lokala cache-filen för iOS
    private var localCacheURL: URL? {
        guard let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("FoodData_iOS Error: Could not find Application Support directory.")
            return nil
        }
        // Skapa underkatalog för cache om den inte finns
        let subDirectory = appSupportDirectory.appendingPathComponent("DataCache")
        do {
            try FileManager.default.createDirectory(at: subDirectory, withIntermediateDirectories: true, attributes: nil)
            return subDirectory.appendingPathComponent("foodListCache_iOS.json") // Unikt namn för iOS-cache
        } catch {
            print("FoodData_iOS Error: Could not create cache subdirectory: \(error)")
            return nil
        }
    }

    init() {
        print("FoodData [iOS]: init called.")

        // 1. Försök ladda från lokal cache synkront
        if loadFoodListLocally() {
            print("FoodData [iOS]: Successfully loaded from local cache.")
            self.isLoading = false // Data finns, dölj initial laddningsindikator
        } else {
            print("FoodData [iOS]: Local cache empty or failed to load.")
            // isLoading förblir true tills CloudKit hämtat data
        }

        // 2. Lyssna på CloudKit-uppdateringssignaler
        CloudKitFoodDataStore.shared.foodListNeedsUpdate
            .sink { [weak self] in
                print("FoodData [iOS]: Received CloudKit update signal. Fetching...")
                self?.loadFoodListFromCloudKit() // Hämta senaste från CloudKit
            }
            .store(in: &cancellables)

        // 3. Starta initial CloudKit-hämtning i bakgrunden
        print("FoodData [iOS]: Initiating background CloudKit fetch from init.")
        loadFoodListFromCloudKit()
    }

    // --- Lokala Cache-funktioner ---
    // (Oförändrade - loadFoodListLocally, saveFoodListLocally)
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
            // Sortera direkt vid laddning
            let sortedList = cachedList.sorted { $0.name.lowercased() < $1.name.lowercased() }
            self.foodList = sortedList
            print("FoodData [iOS]: Successfully loaded \(self.foodList.count) items from cache.")
            return true
        } catch {
            print("FoodData [iOS]: Error loading or decoding local cache: \(error)")
            try? FileManager.default.removeItem(at: url) // Ta bort korrupt fil
            return false
        }
    }

    private func saveFoodListLocally() {
        guard let url = localCacheURL else { return }
        let listToSave = self.foodList // Fånga aktuell lista
        print("FoodData [iOS]: Attempting to save \(listToSave.count) items to cache: \(url.path)")

        DispatchQueue.global(qos: .background).async {
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(listToSave)
                try data.write(to: url, options: [.atomic])
                print("FoodData [iOS]: Successfully saved cache.")
            } catch {
                print("FoodData [iOS]: Error encoding or saving local cache: \(error)")
            }
        }
    }


    // --- CloudKit Fetch ---
    // (Oförändrad - loadFoodListFromCloudKit)
    func loadFoodListFromCloudKit() {
         DispatchQueue.main.async {
            if self.foodList.isEmpty { // Visa bara om cachen var tom
                 self.isLoading = true
            }
         }
        print("FoodData [iOS]: loadFoodListFromCloudKit called.")

        CloudKitFoodDataStore.shared.fetchFoodItems { [weak self] (items, error) in
            guard let self = self else { return }
            print("FoodData [iOS]: CloudKit fetch completion handler started.")

            DispatchQueue.main.async { // Uppdatera UI på huvudtråden
                 self.isLoading = false // Sluta ladda

                 if let error = error {
                     print("FoodData [iOS]: Error fetching from CloudKit: \(error)")
                     // Behåll cachad data vid fel
                     return
                 }

                 let receivedItems = items ?? []
                 print("FoodData [iOS]: CloudKit fetch successful. Received \(receivedItems.count) items.")
                 let sortedReceivedItems = receivedItems.sorted { $0.name.lowercased() < $1.name.lowercased() }

                 if self.foodList != sortedReceivedItems {
                     print("FoodData [iOS]: CloudKit data differs. Updating UI and saving cache.")
                     self.foodList = sortedReceivedItems // Uppdatera UI
                     self.saveFoodListLocally()        // Uppdatera cache
                 } else {
                    print("FoodData [iOS]: CloudKit data same as local. No update.")
                 }
             }
        }
    }


    // --- Modifieringsfunktioner ---
    // (Oförändrade - addFoodItem, updateFoodItem, deleteFoodItem, deleteAllFoodItems)
    func addFoodItem(_ foodItem: FoodItem) {
        DispatchQueue.main.async {
             if !self.foodList.contains(where: { $0.id == foodItem.id }) {
                 self.foodList.append(foodItem)
                 self.sortFoodList()
                 self.saveFoodListLocally() // Spara cache direkt
                 print("FoodData [iOS]: Added item locally & saved cache. ID: \(foodItem.id)")
             } else { return } // Finns redan
        }
        CloudKitFoodDataStore.shared.saveFoodItem(foodItem) { error in // Spara till CloudKit
             if let error = error { print("FoodData Error: CK save failed (add) ID \(foodItem.id): \(error)") }
             else { print("FoodData [iOS]: CK save success (add) ID \(foodItem.id)") }
        }
    }

    func updateFoodItem(_ foodItem: FoodItem) {
        DispatchQueue.main.async {
            if let index = self.foodList.firstIndex(where: { $0.id == foodItem.id }) {
                self.foodList[index] = foodItem
                self.sortFoodList()
                self.saveFoodListLocally() // Spara cache direkt
                print("FoodData [iOS]: Updated item locally & saved cache. ID: \(foodItem.id)")
            } else { return } // Hittades inte
        }
        CloudKitFoodDataStore.shared.saveFoodItem(foodItem) { error in // Spara till CloudKit
             if let error = error { print("FoodData Error: CK save failed (update) ID \(foodItem.id): \(error)") }
             else { print("FoodData [iOS]: CK save success (update) ID \(foodItem.id)") }
        }
    }

    func deleteFoodItem(withId id: UUID) {
        DispatchQueue.main.async {
            let originalCount = self.foodList.count
            self.foodList.removeAll { $0.id == id }
            if self.foodList.count < originalCount { // Om något togs bort
                self.saveFoodListLocally() // Spara cache direkt
                print("FoodData [iOS]: Deleted item locally & saved cache. ID: \(id)")
            } else { return } // Hittades inte
        }
        CloudKitFoodDataStore.shared.deleteFoodItem(withId: id) { error in // Radera från CloudKit
             if let error = error { print("FoodData Error: CK delete failed ID \(id): \(error)") }
             else { print("FoodData [iOS]: CK delete success ID \(id)") }
        }
    }

    func deleteAllFoodItems() {
        let itemsToDelete = self.foodList
        guard !itemsToDelete.isEmpty else { return }
        let recordIDsToDelete = itemsToDelete.map { CKRecord.ID(recordName: $0.id.uuidString) }

        DispatchQueue.main.async { // Töm lokalt direkt
            self.foodList.removeAll()
            self.saveFoodListLocally()
            print("FoodData [iOS]: Deleted all items locally & saved cache.")
        }

        // Radera från CloudKit
        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDsToDelete)
        operation.savePolicy = .allKeys
        operation.modifyRecordsResultBlock = { [weak self] result in
            switch result {
            case .success():
                print("FoodData [iOS]: Successfully deleted all items from CloudKit.")
            case .failure(let error):
                print("FoodData Error: Failed to delete all items from CloudKit: \(error)")
                DispatchQueue.main.async { self?.loadFoodListFromCloudKit() } // Ladda om vid fel
            }
        }
        CloudKitFoodDataStore.shared.database.add(operation)
    }


    // --- CSV Funktioner (Importering modifierad igen för timing) ---

    /// Importerar livsmedel från en CSV-fil till CloudKit och uppdaterar lokalt, **skippar dubbletter baserat på namn**.
    func importFromCSV(fileURL: URL, completion: @escaping (Result<Int, Error>) -> Void) {
        guard !isSavingCSV else {
            print("FoodData [iOS]: Import already in progress.")
            completion(.success(0))
            return
        }
        isSavingCSV = true
        print("FoodData [iOS]: Starting CSV import from \(fileURL.lastPathComponent)...")

        // *** ÄNDRING: Parsa först, kontrollera sen ***
        var parsedItemsFromCSV: [FoodItem] = [] // Lagra alla parsade items här först
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
                            if trimmedColumns.count > 2 {
                                let gramsPerDlString = trimmedColumns[2].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
                                if !gramsPerDlString.isEmpty { gramsPerDl = Double(gramsPerDlString) }
                            }
                            var styckPerGram: Double? = nil
                            if trimmedColumns.count > 3 {
                                let styckPerGramString = trimmedColumns[3].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
                                if !styckPerGramString.isEmpty { styckPerGram = Double(styckPerGramString) }
                            }
                            var isFavorite: Bool = false
                            if trimmedColumns.count > 4 {
                                isFavorite = trimmedColumns[4].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "true"
                            }
                            let newFoodItem = FoodItem(
                                name: name, carbsPer100g: carbsPer100g, grams: 0,
                                gramsPerDl: gramsPerDl, styckPerGram: styckPerGram, isFavorite: isFavorite
                            )
                            parsedItemsFromCSV.append(newFoodItem) // Lägg till i temporär lista

                        } else {
                             if !(name.isEmpty && carbsString.isEmpty && trimmedColumns.count <= 2) {
                                print("FoodData [iOS]: Skipping CSV row \(index + 1) during parse: Invalid carbs ('\(carbsString)') or empty name ('\(name)')")
                             }
                        }
                    } else if !row.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        print("FoodData [iOS]: Skipping CSV row \(index + 1) during parse: Not enough columns (\(trimmedColumns.count))")
                    }
                }
            } catch {
                print("FoodData [iOS]: Error reading CSV file: \(error)")
                parsingError = error // Spara felet
            }
        }

        // Körs när parsing är klar (på huvudtråden)
        parsingGroup.notify(queue: .main) { [weak self] in
            guard let self = self else {
                 completion(.failure(NSError(domain: "FoodData", code: -2, userInfo: [NSLocalizedDescriptionKey: "Self was deallocated"])))
                 return
             }

            // Hantera eventuellt parsing-fel
            if let error = parsingError {
                self.isSavingCSV = false
                completion(.failure(error))
                return
            }

            print("FoodData [iOS]: CSV parsing complete. Parsed \(parsedItemsFromCSV.count) potential items.")

            // *** NYTT: Dubblettkontroll mot aktuell foodList ***
            let currentExistingItemNames = Set(self.foodList.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
            print("FoodData [iOS]: Checking against \(currentExistingItemNames.count) current item names.")

            var itemsToSave: [FoodItem] = []
            var skippedCount = 0

            for item in parsedItemsFromCSV {
                let trimmedLowercasedName = item.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if currentExistingItemNames.contains(trimmedLowercasedName) {
                    print("FoodData [iOS]: Skipping duplicate item: '\(item.name)'")
                    skippedCount += 1
                } else {
                    itemsToSave.append(item)
                }
            }

            print("FoodData [iOS]: Filtering complete. Items to save: \(itemsToSave.count). Duplicates skipped: \(skippedCount).")

            // Om inga nya items finns att spara
            guard !itemsToSave.isEmpty else {
                print("FoodData [iOS]: No valid new items found in CSV to save.")
                self.isSavingCSV = false
                completion(.success(0)) // Rapportera 0 importerade
                return
            }

            // Skapa CloudKit-operation med de filtrerade itemsen
            let recordsToSave = itemsToSave.map { $0.toCKRecord() }
            let operation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: nil)
            operation.savePolicy = .allKeys // Behåll .allKeys för att tillåta CSV att skriva över baserat på ID om det skulle uppstå (dock osannolikt med vår UUID-generering)

            var successfullySavedCount = 0
            operation.perRecordSaveBlock = { recordId, result in
                 switch result {
                 case .success(_): successfullySavedCount += 1
                 case .failure(let error): print("Failed to save record \(recordId.recordName): \(error)")
                 }
             }

            operation.modifyRecordsResultBlock = { [weak self] result in
                // Körs på bakgrundstråd från CloudKit, växla till main
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.isSavingCSV = false // Återställ flaggan oavsett resultat

                    switch result {
                    case .success():
                        print("FoodData [iOS]: CSV Batch save completed. Successfully saved \(successfullySavedCount) of \(itemsToSave.count) new items.")
                        self.loadFoodListFromCloudKit() // Ladda om för att uppdatera UI och cache
                        completion(.success(successfullySavedCount))
                    case .failure(let error):
                        print("FoodData [iOS]: CSV Batch save failed: \(error)")
                        // Ladda om ändå för att se om några poster sparades trots felet
                        self.loadFoodListFromCloudKit()
                        completion(.failure(error))
                    }
                }
            }

            print("FoodData [iOS]: Adding CSV batch save operation to CloudKit database...")
            CloudKitFoodDataStore.shared.database.add(operation)
        }
    }


    /// Exporterar den aktuella `foodList` till en CSV-fil.
    // (Oförändrad - exportToCSV)
    func exportToCSV(completion: @escaping (Result<URL, Error>) -> Void) {
        // Kör exportlogiken i bakgrunden för att inte blockera UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                // Skicka fel om self inte finns
                DispatchQueue.main.async { completion(.failure(NSError(domain: "FoodData", code: -1, userInfo: [NSLocalizedDescriptionKey: "Data source not available"]))) }
                return
            }

             let listToExport = self.foodList // Läses från main thread, men kopieras här
             print("FoodData [iOS]: Starting CSV export for \(listToExport.count) items...")

            // Skapa filnamn och sökväg i temporär katalog
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime]
            let timestamp = dateFormatter.string(from: Date())
            let fileName = "kolkalk_livsmedel_\(timestamp).csv"

            let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

            var csvString = "Name;CarbsPer100g;GramsPerDl;StyckPerGram;IsFavorite\n" // CSV Header

            // Sortera listan för konsekvent export
            let sortedList = listToExport.sorted { $0.name.lowercased() < $1.name.lowercased() }

            for food in sortedList {
                // Hantera semikolon och citattecken i namn för säker CSV
                let name = "\"\(food.name.replacingOccurrences(of: "\"", with: "\"\""))\"" // Dubbla citattecken inom citattecken
                // Formatera nummer med kommatecken som decimalavskiljare
                let carbs = food.carbsPer100g != nil ? String(format: "%.1f", food.carbsPer100g!).replacingOccurrences(of: ".", with: ",") : ""
                let gramsPerDl = food.gramsPerDl != nil ? String(format: "%.1f", food.gramsPerDl!).replacingOccurrences(of: ".", with: ",") : ""
                let styckPerGram = food.styckPerGram != nil ? String(format: "%.1f", food.styckPerGram!).replacingOccurrences(of: ".", with: ",") : ""
                let favorite = food.isFavorite ? "true" : "false"

                // Skapa raden
                let row = "\(name);\(carbs);\(gramsPerDl);\(styckPerGram);\(favorite)\n"
                csvString.append(row)
            }

            do {
                // Skriv till filen med UTF8-kodning
                try csvString.write(to: path, atomically: true, encoding: .utf8)
                print("FoodData [iOS]: CSV file successfully exported to \(path.path)")
                // Anropa completion på huvudtråden med URL:en till den skapade filen
                DispatchQueue.main.async { completion(.success(path)) }
            } catch {
                print("FoodData [iOS]: Error writing CSV file: \(error)")
                // Anropa completion på huvudtråden med felet
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        } // Slut på DispatchQueue.global
    }


    // --- Privat hjälpfunktion ---
    /// Sorterar den interna `foodList` i bokstavsordning (skiftlägesokänsligt).
    // (Oförändrad - sortFoodList)
    private func sortFoodList() {
        self.foodList.sort { $0.name.lowercased() < $1.name.lowercased() }
    }
}
