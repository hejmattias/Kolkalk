// Kolkalk.zip/kolkalk Watch App/FoodData.swift

import SwiftUI
import Foundation
import Combine
import CloudKit

// FoodData-klassen som hanterar listan av livsmedel med lokal cache
class FoodData: ObservableObject {
    // Publicerade variabler som UI kan observera
    @Published var foodList: [FoodItem] = []
    // Visar om en CloudKit-synkronisering pågår (bra för feedback)
    @Published var isLoading: Bool = true
    private var cancellables = Set<AnyCancellable>() // För Combine-prenumerationer

    // URL till den lokala cache-filen
    private var localCacheURL: URL? {
        guard let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("FoodData Error: Could not find Application Support directory.")
            return nil
        }
        let subDirectory = appSupportDirectory.appendingPathComponent("DataCache")
        do {
            // Skapa underkatalog om den inte finns
            try FileManager.default.createDirectory(at: subDirectory, withIntermediateDirectories: true, attributes: nil)
            // Returnera hela sökvägen till cache-filen
            return subDirectory.appendingPathComponent("foodListCache.json")
        } catch {
            print("FoodData Error: Could not create cache subdirectory: \(error)")
            return nil
        }
    }

    init() {
        print("FoodData [Watch]: init called.")

        // 1. Försök ladda från lokal cache först (synkront)
        if loadFoodListLocally() {
            print("FoodData [Watch]: Successfully loaded from local cache.")
            self.isLoading = false // Data finns direkt, sluta visa initial laddning
        } else {
            print("FoodData [Watch]: Local cache empty or failed to load.")
            // isLoading förblir true tills CloudKit-hämtning (nedan) slutförs
        }

        // 2. Lyssna på CloudKit-uppdateringssignaler
        CloudKitFoodDataStore.shared.foodListNeedsUpdate
            .sink { [weak self] in
                print("FoodData [Watch]: Received CloudKit update signal. Fetching...")
                // Hämta senaste datan från CloudKit när en ändring har skett
                self?.loadFoodListFromCloudKit()
            }
            .store(in: &cancellables)

        // 3. Starta initial CloudKit-hämtning i bakgrunden för att säkerställa färsk data
        // Detta körs oavsett om cache-laddningen lyckades, för att få ev. nya ändringar.
        print("FoodData [Watch]: Initiating background CloudKit fetch from init.")
        loadFoodListFromCloudKit()
    }

    // --- Lokala Cache-funktioner ---

    /// Laddar livsmedelslistan från den lokala JSON-cachefilen.
    /// - Returns: `true` om laddningen lyckades, annars `false`.
    private func loadFoodListLocally() -> Bool {
        guard let url = localCacheURL else { return false }
        print("FoodData [Watch]: Attempting to load cache from: \(url.path)")

        // Kontrollera om filen existerar innan läsning
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("FoodData [Watch]: Cache file does not exist at path.")
            return false
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let cachedList = try decoder.decode([FoodItem].self, from: data)

            // Sortera listan direkt vid laddning
            let sortedList = cachedList.sorted { $0.name.lowercased() < $1.name.lowercased() }

            // Uppdatera @Published-variabeln (synkront inom init)
            self.foodList = sortedList
            print("FoodData [Watch]: Successfully loaded and decoded \(self.foodList.count) items from cache.")
            return true
        } catch {
            print("FoodData [Watch]: Error loading or decoding local cache: \(error)")
            // Om filen är korrupt, ta bort den så att ny data kan hämtas
            try? FileManager.default.removeItem(at: url)
            return false
        }
    }

    /// Sparar den aktuella `foodList` till den lokala JSON-cachefilen i en bakgrundstråd.
    private func saveFoodListLocally() {
        guard let url = localCacheURL else { return }
        // Fånga listan som den är *nu* på den tråd som anropar (oftast main)
        let listToSave = self.foodList
        print("FoodData [Watch]: Attempting to save \(listToSave.count) items to cache: \(url.path)")

        // Utför själva filskrivningen asynkront i bakgrunden
        DispatchQueue.global(qos: .background).async {
            do {
                let encoder = JSONEncoder()
                // encoder.outputFormatting = .prettyPrinted // Använd vid behov för felsökning
                let data = try encoder.encode(listToSave)
                // Använd atomisk skrivning för att minska risken för korrupt fil vid avbrott
                try data.write(to: url, options: [.atomic])
                print("FoodData [Watch]: Successfully saved cache.")
            } catch {
                print("FoodData [Watch]: Error encoding or saving local cache: \(error)")
            }
        }
    }

    // --- CloudKit Fetch ---

    /// Hämtar den senaste livsmedelslistan från CloudKit. Uppdaterar UI och lokal cache vid framgång.
    func loadFoodListFromCloudKit() {
        // Visa laddningsindikator om listan är tom eller om detta är en manuell refresh
        DispatchQueue.main.async {
            // Sätt bara isLoading om det verkligen behövs för feedback
             if self.foodList.isEmpty { // Om cachen var tom
                 self.isLoading = true
             }
            // Om man vill ha en indikator *varje* gång CloudKit anropas kan man sätta isLoading = true här alltid.
        }
        print("FoodData [Watch]: loadFoodListFromCloudKit called.")

        CloudKitFoodDataStore.shared.fetchFoodItems { [weak self] (items, error) in
            // Hoppa ur om self inte längre finns (ovanligt men säkert)
            guard let self = self else { return }
            print("FoodData [Watch]: CloudKit fetch completion handler started.")

            // Växla till huvudtråden för att uppdatera UI (@Published variabler)
            DispatchQueue.main.async {
                 self.isLoading = false // Sluta visa laddningsindikatorn

                 if let error = error {
                     print("FoodData [Watch]: Error fetching from CloudKit: \(error)")
                     // Vid fel: Behåll den data som finns (från cache). Visa ev. felmeddelande för användaren.
                     return
                 }

                 let receivedItems = items ?? []
                 print("FoodData [Watch]: CloudKit fetch successful. Received \(receivedItems.count) items.")

                 // Sortera den mottagna listan
                 let sortedReceivedItems = receivedItems.sorted { $0.name.lowercased() < $1.name.lowercased() }

                 // Jämför med nuvarande lista för att undvika onödig UI-uppdatering och cache-skrivning
                 // Kräver att FoodItem är Equatable (vilket den är i din kod)
                 if self.foodList != sortedReceivedItems {
                     print("FoodData [Watch]: CloudKit data differs from local. Updating UI and saving cache.")
                     self.foodList = sortedReceivedItems // Uppdatera UI
                     self.saveFoodListLocally()        // Uppdatera lokal cache
                 } else {
                    print("FoodData [Watch]: CloudKit data is the same as local. No update needed.")
                 }
             }
        }
    }

    // --- Modifieringsfunktioner (Uppdaterar lokalt först, sedan CloudKit) ---

    /// Lägger till ett nytt livsmedel lokalt och i CloudKit.
    func addFoodItem(_ foodItem: FoodItem) {
         DispatchQueue.main.async { // Säkerställ att @Published ändras på huvudtråden
             // Undvik dubbletter (baserat på ID)
             if !self.foodList.contains(where: { $0.id == foodItem.id }) {
                 self.foodList.append(foodItem)
                 self.sortFoodList()        // Håll listan sorterad
                 self.saveFoodListLocally() // Spara den nya listan till cache direkt
                 print("FoodData [Watch]: Added item locally & saved cache. ID: \(foodItem.id)")
             } else {
                 print("FoodData [Watch]: Item with ID \(foodItem.id) already exists locally. Skipping add.")
                 return // Avbryt om den redan finns lokalt
             }
         }

         // Skicka till CloudKit i bakgrunden
         CloudKitFoodDataStore.shared.saveFoodItem(foodItem) { error in
             if let error = error {
                 print("FoodData Error: Failed to save added item \(foodItem.id) to CloudKit: \(error)")
                 // Överväg att ta bort den lokalt igen eller meddela användaren
             } else {
                 print("FoodData [Watch]: Successfully saved added item \(foodItem.id) to CloudKit.")
             }
         }
     }

     /// Uppdaterar ett befintligt livsmedel lokalt och i CloudKit.
     func updateFoodItem(_ foodItem: FoodItem) {
          DispatchQueue.main.async {
              if let index = self.foodList.firstIndex(where: { $0.id == foodItem.id }) {
                  self.foodList[index] = foodItem
                  self.sortFoodList()
                  self.saveFoodListLocally() // Spara ändringen till cache direkt
                  print("FoodData [Watch]: Updated item locally & saved cache. ID: \(foodItem.id)")
              } else {
                 print("FoodData [Watch]: Item with ID \(foodItem.id) not found locally. Cannot update.")
                  return // Avbryt om den inte finns lokalt
              }
          }

          // Skicka till CloudKit i bakgrunden
          CloudKitFoodDataStore.shared.saveFoodItem(foodItem) { error in
              if let error = error {
                  print("FoodData Error: Failed to save updated item \(foodItem.id) to CloudKit: \(error)")
                  // Överväg att återställa den lokala ändringen eller meddela användaren
              } else {
                   print("FoodData [Watch]: Successfully saved updated item \(foodItem.id) to CloudKit.")
              }
          }
      }

      /// Raderar ett livsmedel lokalt och från CloudKit.
      func deleteFoodItem(withId id: UUID) {
           DispatchQueue.main.async {
               let originalCount = self.foodList.count
               self.foodList.removeAll { $0.id == id }
               // Kontrollera om något faktiskt togs bort innan vi sparar cachen
               if self.foodList.count < originalCount {
                   self.saveFoodListLocally() // Spara den nya listan till cache direkt
                   print("FoodData [Watch]: Deleted item locally & saved cache. ID: \(id)")
               } else {
                  print("FoodData [Watch]: Item with ID \(id) not found locally. Cannot delete.")
                   return // Avbryt om den inte fanns lokalt
               }
           }

           // Skicka till CloudKit i bakgrunden
           CloudKitFoodDataStore.shared.deleteFoodItem(withId: id) { error in
               if let error = error {
                   print("FoodData Error: Failed to delete item \(id) from CloudKit: \(error)")
                   // Överväg att lägga tillbaka den lokalt eller meddela användaren
               } else {
                   print("FoodData [Watch]: Successfully deleted item \(id) from CloudKit.")
               }
           }
      }

      /// Raderar alla livsmedel lokalt och från CloudKit.
      func deleteAllFoodItems() {
          // Kopiera listan med ID:n *innan* den lokala listan töms
          let itemsToDelete = self.foodList
          guard !itemsToDelete.isEmpty else {
             print("FoodData [Watch]: deleteAllFoodItems called, but list is already empty.")
             return
          }
          let recordIDsToDelete = itemsToDelete.map { CKRecord.ID(recordName: $0.id.uuidString) }

           DispatchQueue.main.async {
               self.foodList.removeAll()
               self.saveFoodListLocally() // Spara den tomma listan till cache direkt
               print("FoodData [Watch]: Deleted all items locally & saved cache.")
           }

          // Skicka till CloudKit i bakgrunden
          let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDsToDelete)
          operation.savePolicy = .allKeys // Radera även om posten ändrats sedan hämtning
          operation.modifyRecordsResultBlock = { [weak self] result in
               // Körs på en bakgrundstråd från CloudKit
               switch result {
               case .success():
                   print("FoodData [Watch]: Successfully deleted all items from CloudKit.")
               case .failure(let error):
                   print("FoodData Error: Failed to delete all items from CloudKit: \(error)")
                   // Ladda om listan från CloudKit för att återställa till korrekt status
                   DispatchQueue.main.async { // Växla till main för att anropa funktionen
                       self?.loadFoodListFromCloudKit()
                   }
               }
           }
          CloudKitFoodDataStore.shared.database.add(operation)
      }

    // Privat funktion för att sortera listan (anropas internt)
    private func sortFoodList() {
        // Eftersom detta ofta anropas från main thread redan,
        // och @Published triggar UI-uppdatering från main,
        // behövs oftast ingen explicit dispatch här.
        self.foodList.sort { $0.name.lowercased() < $1.name.lowercased() }
    }
}
