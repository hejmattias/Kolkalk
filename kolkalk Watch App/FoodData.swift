// Kolkalk.zip/kolkalk Watch App/FoodData.swift

import SwiftUI
import Foundation
import Combine
import CloudKit

class FoodData: ObservableObject {
    @Published var foodList: [FoodItem] = []
    @Published var isLoading: Bool = true
    @Published var lastSyncTime: Date? = nil
    @Published var lastSyncError: Error? = nil
    private var cancellables = Set<AnyCancellable>()

    private var localCacheURL: URL? {
        guard let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("FoodData Error [Watch]: Could not find Application Support directory.")
            return nil
        }
        let subDirectory = appSupportDirectory.appendingPathComponent("DataCache")
        do {
            try FileManager.default.createDirectory(at: subDirectory, withIntermediateDirectories: true, attributes: nil)
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
        let listToSave = self.foodList // Spara den aktuella listan
        print("FoodData [Watch]: Attempting to save \(listToSave.count) items to cache: \(url.path)")
        DispatchQueue.global(qos: .background).async {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted // Gör JSON-filen mer läsbar vid felsökning
                let data = try encoder.encode(listToSave)
                try data.write(to: url, options: [.atomic])
                print("FoodData [Watch]: Successfully saved cache.")
            } catch {
                print("FoodData [Watch]: Error encoding or saving local cache: \(error)")
            }
        }
    }

    func loadFoodListFromCloudKit() {
        DispatchQueue.main.async {
             if !self.isLoading {
                 print("FoodData [Watch]: Setting isLoading = true for CloudKit fetch.")
                 self.isLoading = true
             }
            self.lastSyncError = nil
        }
        print("FoodData [Watch]: loadFoodListFromCloudKit called.")

        // Använder den uppdaterade fetchFoodItems från CloudKitFoodDataStore
        CloudKitFoodDataStore.shared.fetchFoodItems { [weak self] (items, error) in
            guard let self = self else { return }
            print("FoodData [Watch]: CloudKit fetch completion handler started.")

            DispatchQueue.main.async {
                print("FoodData [Watch]: Setting isLoading = false post CloudKit fetch.")
                self.isLoading = false

                if let error = error {
                    print("FoodData [Watch]: Error fetching from CloudKit: \(error.localizedDescription)")
                    self.lastSyncError = error
                    // Behåll den gamla listan vid fel, eller töm? Beror på önskat beteende.
                    // För nu behåller vi den gamla listan.
                    return
                }

                 self.lastSyncError = nil
                 self.lastSyncTime = Date()

                let receivedItems = items ?? []
                print("FoodData [Watch]: CloudKit fetch successful. Received \(receivedItems.count) items.")
                let sortedReceivedItems = receivedItems.sorted { $0.name.lowercased() < $1.name.lowercased() }

                // Jämför om listorna faktiskt skiljer sig åt för att undvika onödiga UI-uppdateringar och cachning.
                if self.foodList != sortedReceivedItems {
                    print("FoodData [Watch]: CloudKit data differs from local. Updating UI and saving cache.")
                    self.foodList = sortedReceivedItems
                    self.saveFoodListLocally() // Spara den nya, kompletta listan
                } else {
                   print("FoodData [Watch]: CloudKit data is the same as local. No UI update or cache save needed.")
                }
            }
        }
    }

    func addFoodItem(_ foodItem: FoodItem) {
         DispatchQueue.main.async {
             if !self.foodList.contains(where: { $0.id == foodItem.id }) {
                 self.foodList.append(foodItem)
                 self.sortFoodList()
                 self.saveFoodListLocally()
                 print("FoodData [Watch]: Optimistically added item \(foodItem.id) locally & saved cache.")
             } else {
                 print("FoodData [Watch]: Add operation aborted. Item with ID \(foodItem.id) already exists locally.")
                 return
             }
         }

         CloudKitFoodDataStore.shared.saveFoodItem(foodItem) { [weak self] error in
             DispatchQueue.main.async {
                 guard let self = self else { return }
                 if let error = error {
                     print("FoodData Error [Watch]: Failed to save added item \(foodItem.id) to CloudKit: \(error.localizedDescription)")
                     self.lastSyncError = error
                     // Överväg att ta bort det optimistiskt tillagda objektet om CloudKit-sparandet misslyckades,
                     // och återställa saveFoodListLocally().
                     // self.foodList.removeAll { $0.id == foodItem.id }
                     // self.sortFoodList()
                     // self.saveFoodListLocally()
                 } else {
                     print("FoodData [Watch]: Successfully saved added item \(foodItem.id) to CloudKit.")
                     self.lastSyncTime = Date()
                     self.lastSyncError = nil
                     
                     // *** FÖRFINAT SÄKERHETSNÄT för addFoodItem ***
                     let itemID = foodItem.id
                     if let index = self.foodList.firstIndex(where: { $0.id == itemID }) {
                         // Objektet finns, säkerställ att det är den version vi menade att spara.
                         if self.foodList[index] != foodItem {
                             print("FoodData [Watch]: Updating existing local item \(itemID) to match successfully saved version post-CloudKit add.")
                             self.foodList[index] = foodItem
                             self.sortFoodList()
                             self.saveFoodListLocally()
                         } else {
                             // print("FoodData [Watch]: Local item \(itemID) already matches successfully saved version after add.")
                         }
                     } else {
                         // Objektet finns inte lokalt, lägg tillbaka det.
                         // Detta täcker fallet där det optimistiskt lades till och sedan togs bort av en snabb, ofullständig synk.
                         print("FoodData [Watch]: Re-adding item \(itemID) to local list post-CloudKit add, as it was missing.")
                         self.foodList.append(foodItem)
                         self.sortFoodList()
                         self.saveFoodListLocally()
                     }
                     // *** SLUT FÖRFINAT SÄKERHETSNÄT ***
                 }
             }
         }
     }

     func updateFoodItem(_ foodItem: FoodItem) {
          DispatchQueue.main.async {
              if let index = self.foodList.firstIndex(where: { $0.id == foodItem.id }) {
                  self.foodList[index] = foodItem
                  self.sortFoodList()
                  self.saveFoodListLocally()
                  print("FoodData [Watch]: Optimistically updated item \(foodItem.id) locally & saved cache.")
              } else {
                  print("FoodData [Watch]: Item to update \(foodItem.id) not found locally for optimistic update. Will attempt CloudKit save.")
              }
          }

          CloudKitFoodDataStore.shared.saveFoodItem(foodItem) { [weak self] error in
              DispatchQueue.main.async {
                 guard let self = self else { return }
                 if let error = error {
                     print("FoodData Error [Watch]: Failed to save updated item \(foodItem.id) to CloudKit: \(error.localizedDescription)")
                     self.lastSyncError = error
                 } else {
                     print("FoodData [Watch]: Successfully saved updated item \(foodItem.id) to CloudKit.")
                     self.lastSyncTime = Date()
                     self.lastSyncError = nil
                     
                     // *** FÖRFINAT SÄKERHETSNÄT för updateFoodItem ***
                     let itemID = foodItem.id
                     if let index = self.foodList.firstIndex(where: { $0.id == itemID }) {
                         // Objektet finns, säkerställ att det är den version vi menade att spara.
                         if self.foodList[index] != foodItem {
                             print("FoodData [Watch]: Updating local item \(itemID) to match successfully saved version post-CloudKit update.")
                             self.foodList[index] = foodItem
                             self.sortFoodList()
                             self.saveFoodListLocally()
                         } else {
                             // print("FoodData [Watch]: Local item \(itemID) already matches successfully saved version after update.")
                         }
                     } else {
                         // Objektet finns inte lokalt (kanske raderat av en synk), men vi lyckades uppdatera det i CloudKit.
                         // Lägg tillbaka det med den uppdaterade informationen.
                         print("FoodData [Watch]: Re-adding updated item \(itemID) to local list post-CloudKit update, as it was missing.")
                         self.foodList.append(foodItem)
                         self.sortFoodList()
                         self.saveFoodListLocally()
                     }
                     // *** SLUT FÖRFINAT SÄKERHETSNÄT ***
                 }
             }
          }
      }

      func deleteFoodItem(withId id: UUID) {
           DispatchQueue.main.async {
               let originalCount = self.foodList.count
               self.foodList.removeAll { $0.id == id }
               if self.foodList.count < originalCount {
                   self.saveFoodListLocally()
                   print("FoodData [Watch]: Deleted item \(id) locally & saved cache.")
               } else {
                   print("FoodData [Watch]: Delete aborted for item \(id), not found locally.")
                   return
               }
           }

           CloudKitFoodDataStore.shared.deleteFoodItem(withId: id) { [weak self] error in
               DispatchQueue.main.async {
                 guard let self = self else { return }
                 if let error = error {
                     print("FoodData Error [Watch]: Failed to delete item \(id) from CloudKit: \(error.localizedDescription)")
                     self.lastSyncError = error
                     // Ladda om listan från CloudKit för att återställa till serverns tillstånd vid fel.
                     self.loadFoodListFromCloudKit()
                 } else {
                     print("FoodData [Watch]: Successfully deleted item \(id) from CloudKit.")
                     self.lastSyncTime = Date()
                     self.lastSyncError = nil
                 }
             }
           }
      }

      func deleteAllFoodItems() {
          let itemsToDelete = self.foodList
          guard !itemsToDelete.isEmpty else {
              print("FoodData [Watch]: deleteAllFoodItems called, but list is already empty.");
              return
          }
          let recordIDsToDelete = itemsToDelete.map { CKRecord.ID(recordName: $0.id.uuidString) }

           DispatchQueue.main.async {
               self.foodList.removeAll()
               self.saveFoodListLocally()
               print("FoodData [Watch]: Deleted all items locally & saved cache.")
           }

          CloudKitFoodDataStore.shared.deleteAllFoodItems(recordIDsToDelete: recordIDsToDelete) { [weak self] error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if let error = error {
                        print("FoodData Error [Watch]: Failed to delete all items from CloudKit: \(error.localizedDescription)")
                        self.lastSyncError = error
                        self.loadFoodListFromCloudKit()
                    } else {
                        print("FoodData [Watch]: Successfully deleted all items from CloudKit via deleteAllFoodItems.")
                        self.lastSyncTime = Date()
                        self.lastSyncError = nil
                    }
                }
            }
      }

    private func sortFoodList() {
        DispatchQueue.main.async {
            self.foodList.sort { $0.name.lowercased() < $1.name.lowercased() }
        }
    }
}
