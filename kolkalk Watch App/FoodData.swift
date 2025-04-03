// Kolkalk.zip/kolkalk Watch App/FoodData.swift

import SwiftUI
import Foundation
import Combine
import CloudKit

class FoodData: ObservableObject {
    @Published var foodList: [FoodItem] = []
    @Published var isLoading: Bool = true
    @Published var lastSyncTime: Date? = nil // Tid för senaste lyckade synk (hämtning eller push)
    @Published var lastSyncError: Error? = nil // Senaste felet vid synk
    private var cancellables = Set<AnyCancellable>()

    // localCacheURL och init (oförändrade)
    private var localCacheURL: URL? {
        guard let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("FoodData Error [Watch]: Could not find Application Support directory.")
            return nil
        }
        let subDirectory = appSupportDirectory.appendingPathComponent("DataCache")
        do {
            try FileManager.default.createDirectory(at: subDirectory, withIntermediateDirectories: true, attributes: nil)
            // Använd samma namn som iOS om du vill att de ska dela cache via iCloud Drive?
            // Eller ett unikt namn för klockan. Vi antar unikt nu.
            return subDirectory.appendingPathComponent("foodListCache_watch.json")
        } catch {
            print("FoodData Error [Watch]: Could not create cache subdirectory: \(error)")
            return nil
        }
    }

     init() {
         print("FoodData [Watch]: init called.")
         if loadFoodListLocally() {
             print("FoodData [Watch]: Successfully loaded from local cache.")
             self.isLoading = false
         } else {
             print("FoodData [Watch]: Local cache empty or failed to load.")
         }
         CloudKitFoodDataStore.shared.foodListNeedsUpdate
             .sink { [weak self] in
                 print("FoodData [Watch]: Received CloudKit update signal. Fetching...")
                 self?.loadFoodListFromCloudKit()
             }
             .store(in: &cancellables)
         print("FoodData [Watch]: Initiating background CloudKit fetch from init.")
         loadFoodListFromCloudKit()
     }

    // loadFoodListLocally och saveFoodListLocally (oförändrade)
    private func loadFoodListLocally() -> Bool {
        guard let url = localCacheURL else { return false }
        print("FoodData [Watch]: Attempting to load cache from: \(url.path)")
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("FoodData [Watch]: Cache file does not exist at path.")
            return false
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let cachedList = try decoder.decode([FoodItem].self, from: data)
            let sortedList = cachedList.sorted { $0.name.lowercased() < $1.name.lowercased() }
            // Måste köras på main thread eftersom det uppdaterar @Published
            DispatchQueue.main.async {
                self.foodList = sortedList
                print("FoodData [Watch]: Successfully loaded and decoded \(self.foodList.count) items from cache.")
            }
            return true
        } catch {
            print("FoodData [Watch]: Error loading or decoding local cache: \(error)")
            try? FileManager.default.removeItem(at: url)
            return false
        }
    }

    private func saveFoodListLocally() {
        guard let url = localCacheURL else { return }
        let listToSave = self.foodList
        print("FoodData [Watch]: Attempting to save \(listToSave.count) items to cache: \(url.path)")
        DispatchQueue.global(qos: .background).async { // Spara i bakgrunden
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(listToSave)
                try data.write(to: url, options: [.atomic])
                print("FoodData [Watch]: Successfully saved cache.")
            } catch {
                print("FoodData [Watch]: Error encoding or saving local cache: \(error)")
            }
        }
    }


    // loadFoodListFromCloudKit (sätter lastSyncTime vid lyckad HÄMTNING)
    func loadFoodListFromCloudKit() {
        DispatchQueue.main.async {
            // Undvik att sätta isLoading om vi redan laddar
             if !self.isLoading {
                 print("FoodData [Watch]: Setting isLoading = true.")
                 self.isLoading = true
             }
            // Nollställ fel inför ny hämtning
            self.lastSyncError = nil
        }
        print("FoodData [Watch]: loadFoodListFromCloudKit called.")

        CloudKitFoodDataStore.shared.fetchFoodItems { [weak self] (items, error) in
            guard let self = self else { return }
            print("FoodData [Watch]: CloudKit fetch completion handler started.")

            DispatchQueue.main.async {
                print("FoodData [Watch]: Setting isLoading = false.")
                self.isLoading = false // Sluta ladda (alltid)

                if let error = error {
                    print("FoodData [Watch]: Error fetching from CloudKit: \(error)")
                    self.lastSyncError = error // Spara felet
                    return
                }

                // *** Sätter tiden vid lyckad HÄMTNING ***
                 self.lastSyncError = nil
                 self.lastSyncTime = Date()

                let receivedItems = items ?? []
                print("FoodData [Watch]: CloudKit fetch successful. Received \(receivedItems.count) items.")
                let sortedReceivedItems = receivedItems.sorted { $0.name.lowercased() < $1.name.lowercased() }

                if self.foodList != sortedReceivedItems {
                    print("FoodData [Watch]: CloudKit data differs from local. Updating UI and saving cache.")
                    self.foodList = sortedReceivedItems
                    self.saveFoodListLocally()
                } else {
                   print("FoodData [Watch]: CloudKit data is the same as local. No update needed.")
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
                 print("FoodData [Watch]: Added item locally & saved cache. ID: \(foodItem.id)")
             } else { return }
         }

         // Skicka till CloudKit
         CloudKitFoodDataStore.shared.saveFoodItem(foodItem) { [weak self] error in
             // *** ÄNDRING: Uppdatera lastSyncTime vid lyckad save ***
             DispatchQueue.main.async { // Säkerställ main thread
                 guard let self = self else { return }
                 if let error = error {
                     print("FoodData Error [Watch]: Failed to save added item \(foodItem.id) to CloudKit: \(error)")
                     self.lastSyncError = error // Spara felet
                 } else {
                     print("FoodData [Watch]: Successfully saved added item \(foodItem.id) to CloudKit.")
                     self.lastSyncTime = Date() // Sätt tiden
                     self.lastSyncError = nil // Nollställ felet
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
                  print("FoodData [Watch]: Updated item locally & saved cache. ID: \(foodItem.id)")
              } else { return }
          }

          // Skicka till CloudKit
          CloudKitFoodDataStore.shared.saveFoodItem(foodItem) { [weak self] error in
              // *** ÄNDRING: Uppdatera lastSyncTime vid lyckad save ***
              DispatchQueue.main.async { // Säkerställ main thread
                 guard let self = self else { return }
                 if let error = error {
                     print("FoodData Error [Watch]: Failed to save updated item \(foodItem.id) to CloudKit: \(error)")
                     self.lastSyncError = error // Spara felet
                 } else {
                     print("FoodData [Watch]: Successfully saved updated item \(foodItem.id) to CloudKit.")
                     self.lastSyncTime = Date() // Sätt tiden
                     self.lastSyncError = nil // Nollställ felet
                 }
             }
             // *** SLUT ÄNDRING ***
          }
      }

      func deleteFoodItem(withId id: UUID) {
           // Optimistisk UI-uppdatering (oförändrad)
           DispatchQueue.main.async {
               let originalCount = self.foodList.count
               self.foodList.removeAll { $0.id == id }
               if self.foodList.count < originalCount {
                   self.saveFoodListLocally()
                   print("FoodData [Watch]: Deleted item locally & saved cache. ID: \(id)")
               } else { return }
           }

           // Skicka till CloudKit
           CloudKitFoodDataStore.shared.deleteFoodItem(withId: id) { [weak self] error in
               // *** ÄNDRING: Uppdatera lastSyncTime vid lyckad delete ***
               DispatchQueue.main.async { // Säkerställ main thread
                 guard let self = self else { return }
                 if let error = error {
                     print("FoodData Error [Watch]: Failed to delete item \(id) from CloudKit: \(error)")
                     self.lastSyncError = error // Spara felet
                     // Återställ genom att ladda om vid fel?
                     self.loadFoodListFromCloudKit()
                 } else {
                     print("FoodData [Watch]: Successfully deleted item \(id) from CloudKit.")
                     self.lastSyncTime = Date() // Sätt tiden
                     self.lastSyncError = nil // Nollställ felet
                 }
             }
             // *** SLUT ÄNDRING ***
           }
      }

      func deleteAllFoodItems() {
          let itemsToDelete = self.foodList
          guard !itemsToDelete.isEmpty else {
              print("FoodData [Watch]: deleteAllFoodItems called, but list is already empty.");
              return
          }
          let recordIDsToDelete = itemsToDelete.map { CKRecord.ID(recordName: $0.id.uuidString) }

          // Optimistisk UI-uppdatering (oförändrad)
           DispatchQueue.main.async {
               self.foodList.removeAll()
               self.saveFoodListLocally()
               print("FoodData [Watch]: Deleted all items locally & saved cache.")
           }

           // Använd CloudKitDataStore för att radera
           // (Förutsätter att deleteAllFoodItems i CloudKitStore tar emot IDs och completion)
          CloudKitFoodDataStore.shared.deleteAllFoodItems(recordIDsToDelete: recordIDsToDelete) { [weak self] error in
                // *** ÄNDRING: Uppdatera lastSyncTime vid lyckad deleteAll ***
                DispatchQueue.main.async { // Säkerställ main thread
                    guard let self = self else { return }
                    if let error = error {
                        print("FoodData Error [Watch]: Failed to delete all items from CloudKit: \(error)")
                        self.lastSyncError = error // Spara felet
                        // Ladda om vid fel
                        self.loadFoodListFromCloudKit()
                    } else {
                        print("FoodData [Watch]: Successfully deleted all items from CloudKit via deleteAllFoodItems.")
                        self.lastSyncTime = Date() // Sätt tiden
                        self.lastSyncError = nil // Nollställ felet
                    }
                }
                // *** SLUT ÄNDRING ***
            }
      }

    // sortFoodList (oförändrad)
    private func sortFoodList() {
        // Kan köras på main thread eftersom den muterar @Published property
        DispatchQueue.main.async {
            self.foodList.sort { $0.name.lowercased() < $1.name.lowercased() }
        }
    }
}
