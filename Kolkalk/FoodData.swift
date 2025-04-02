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

    /// Laddar livsmedelslistan från den lokala JSON-cachefilen.
    /// - Returns: `true` om laddningen lyckades, annars `false`.
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

    /// Sparar den aktuella `foodList` till den lokala JSON-cachefilen i en bakgrundstråd.
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

    /// Hämtar den senaste livsmedelslistan från CloudKit. Uppdaterar UI och lokal cache.
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

    /// Lägger till ett nytt livsmedel lokalt och i CloudKit.
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

    /// Uppdaterar ett befintligt livsmedel lokalt och i CloudKit.
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

    /// Raderar ett livsmedel lokalt och från CloudKit.
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

    /// Raderar alla livsmedel lokalt och från CloudKit.
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

    // --- CSV Funktioner (Behållna och korrigerade) ---

    /// Importerar livsmedel från en CSV-fil till CloudKit och uppdaterar lokalt.
    func importFromCSV(fileURL: URL, completion: @escaping (Result<Int, Error>) -> Void) {
        guard !isSavingCSV else {
            print("FoodData [iOS]: Already saving CSV data.")
            completion(.success(0)) // Gör inget om import redan pågår
            return
        }
        isSavingCSV = true // Sätt flagga
        print("FoodData [iOS]: Starting CSV import from \(fileURL.lastPathComponent)...")

        var importedCount = 0
        var itemsToSave: [FoodItem] = []
        let parsingGroup = DispatchGroup() // Använd DispatchGroup för att vänta på parsing

        parsingGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async { // Parsa i bakgrunden
            defer { parsingGroup.leave() } // Körs alltid när blocket avslutas
            do {
                let data = try String(contentsOf: fileURL, encoding: .utf8)
                let rows = data.components(separatedBy: .newlines)
                print("FoodData [iOS]: CSV rows found: \(rows.count)")

                for (index, row) in rows.enumerated() where !row.isEmpty {
                    let columns = row.components(separatedBy: ";")
                    // Trimma extra citattecken om de finns
                    let trimmedColumns = columns.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }


                    if trimmedColumns.count >= 2 {
                        let name = trimmedColumns[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        let carbsString = trimmedColumns[1].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")

                        // Kontrollera att namn inte är tomt och att kolhydrater är giltiga
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
                            // Skapa FoodItem direkt
                             let newFoodItem = FoodItem(
                                 name: name, carbsPer100g: carbsPer100g, grams: 0, // Grams är irrelevant för listan
                                 gramsPerDl: gramsPerDl, styckPerGram: styckPerGram, isFavorite: isFavorite
                             )
                             itemsToSave.append(newFoodItem)
                             importedCount += 1 // Räkna bara giltiga rader som faktiskt läggs till
                        } else {
                            // Logga om viktiga fält saknas eller är ogiltiga, men inte för helt tomma rader
                             if !(name.isEmpty && carbsString.isEmpty && trimmedColumns.count <= 2) {
                                print("FoodData [iOS]: Skipping CSV row \(index + 1): Invalid carbs ('\(carbsString)') or empty name ('\(name)')")
                             }
                        }
                    } else if !row.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        // Logga om raden inte är tom men har för få kolumner
                        print("FoodData [iOS]: Skipping CSV row \(index + 1): Not enough columns (\(trimmedColumns.count))")
                    }
                } // Slut på for-loop
            } catch {
                print("FoodData [iOS]: Error reading CSV file: \(error)")
                // Anropa completion med fel på huvudtråden direkt
                DispatchQueue.main.async {
                    self.isSavingCSV = false // Återställ flagga
                    completion(.failure(error))
                }
                return // Avsluta bakgrundstråden
            }
        } // Slut på DispatchQueue.global

        // Detta körs när parsingGroup är klar (dvs. när parsing-tråden är färdig)
        parsingGroup.notify(queue: .main) { // Växla till huvudtråden för CloudKit-operation
            print("FoodData [iOS]: CSV parsing complete. Items parsed: \(importedCount). Items to save: \(itemsToSave.count)")
            guard !itemsToSave.isEmpty else {
                print("FoodData [iOS]: No valid items found in CSV to save.")
                self.isSavingCSV = false // Återställ flagga
                completion(.success(0)) // Rapportera 0 importerade
                return
            }

            // Skapa CKRecord-objekt och en batch-operation
            let recordsToSave = itemsToSave.map { $0.toCKRecord() }
            let operation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: nil)
            // Använd .allKeys för att skriva över befintliga med samma ID från CSV
            operation.savePolicy = .allKeys

            var successfullySavedCount = 0
            // Valfritt: Följ framsteg per post
             operation.perRecordSaveBlock = { recordId, result in
                  switch result {
                  case .success(_):
                      successfullySavedCount += 1
                  case .failure(let error):
                      print("Failed to save record \(recordId.recordName): \(error)")
                  }
              }

            // Denna körs när *hela* batch-operationen är klar
            operation.modifyRecordsResultBlock = { [weak self] result in
                // Körs på en bakgrundstråd från CloudKit, växla till main
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.isSavingCSV = false // Återställ flagga

                    switch result {
                    case .success():
                        print("FoodData [iOS]: CSV Batch save completed. Successfully saved \(successfullySavedCount) of \(itemsToSave.count) items.")
                        self.loadFoodListFromCloudKit() // Ladda om för att uppdatera lokalt och cache
                        completion(.success(successfullySavedCount)) // Rapportera lyckat antal
                    case .failure(let error):
                        print("FoodData [iOS]: CSV Batch save failed: \(error)")
                         self.loadFoodListFromCloudKit() // Ladda om för att se aktuellt läge
                        completion(.failure(error)) // Rapportera felet
                    }
                }
            }
            print("FoodData [iOS]: Adding CSV batch save operation to CloudKit database...")
            CloudKitFoodDataStore.shared.database.add(operation)
        } // Slut på parsingGroup.notify
    }

    /// Exporterar den aktuella `foodList` till en CSV-fil.
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

            // *** KORRIGERING VAR HÄR - guard let borttagen ***
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
    private func sortFoodList() {
        self.foodList.sort { $0.name.lowercased() < $1.name.lowercased() }
    }
}
