// Kolkalk/Shared/CloudKitFoodDataStore.swift

import Foundation
import CloudKit
import Combine

class CloudKitFoodDataStore {
    static let shared = CloudKitFoodDataStore()

    let container: CKContainer
    lazy var database = container.privateCloudDatabase
    let foodRecordType = "FoodItemRecord"

    let foodListNeedsUpdate = PassthroughSubject<Void, Never>()

    private init() {
        let containerIdentifier = "iCloud.MG.kolkylator" // Ditt fungerande ID
        container = CKContainer(identifier: containerIdentifier)
        print("CloudKitFoodDataStore initialized. Using container: \(containerIdentifier)")
        subscribeToChanges()
    }

    // MARK: - Fetch & Subscription

    // *** ÄNDRAD: Använder nu CKQueryOperation för mer robust hämtning ***
    func fetchFoodItems(completion: @escaping ([FoodItem]?, Error?) -> Void) {
        print("CloudKitStore: fetchFoodItems called (using CKQueryOperation).")
        let query = CKQuery(recordType: foodRecordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

        var accumulatedFoodItems: [FoodItem] = []
        var firstOperationError: Error? = nil // För att spara det första felet som uppstår

        // Rekursiv funktion för att hantera cursors (för att hämta data i omgångar)
        func performQuery(cursor: CKQueryOperation.Cursor?) {
            let queryOperation: CKQueryOperation
            if let cursor = cursor {
                queryOperation = CKQueryOperation(cursor: cursor)
                print("CloudKitStore: Performing query with cursor.")
            } else {
                queryOperation = CKQueryOperation(query: query)
                print("CloudKitStore: Performing initial query.")
            }

            // Sätt en rimlig gräns för resultat per omgång.
            // CloudKit hanterar den faktiska maxgränsen, men detta kan hjälpa till med minneshantering.
            queryOperation.resultsLimit = 200 // Standardrekommendation är ofta 100-200

            // Denna block körs för varje CKRecord som matchar frågan.
            queryOperation.recordMatchedBlock = { recordID, recordResult in
                switch recordResult {
                case .success(let record):
                    if let foodItem = FoodItem(record: record) {
                        accumulatedFoodItems.append(foodItem)
                    } else {
                        print("CloudKitStore: Error parsing FoodItem from record \(recordID.recordName) in recordMatchedBlock.")
                        // Du kan välja att samla dessa fel om det är viktigt
                    }
                case .failure(let error):
                    print("CloudKitStore: Error fetching individual record \(recordID.recordName) in recordMatchedBlock: \(error.localizedDescription)")
                    // Spara det första felet som uppstod under hämtningen av enskilda poster
                    if firstOperationError == nil {
                        firstOperationError = error
                    }
                }
            }

            // Denna block körs när en query-omgång är klar.
            queryOperation.queryResultBlock = { result in
                switch result {
                case .success(let nextCursor):
                    if let nextCursor = nextCursor {
                        // Det finns fler resultat, fortsätt hämta nästa omgång
                        print("CloudKitStore: CKQueryOperation got cursor, fetching next batch...")
                        performQuery(cursor: nextCursor)
                    } else {
                        // Inga fler resultat, hela operationen är klar
                        print("CloudKitStore: CKQueryOperation finished. Total items fetched: \(accumulatedFoodItems.count).")
                        // Om ett fel uppstod under hämtning av enskilda poster, men operationen i övrigt lyckades,
                        // skicka med de ackumulerade objekten och det första felet.
                        if firstOperationError != nil {
                             print("CloudKitStore: CKQueryOperation completed but encountered record-level errors. First error: \(firstOperationError!.localizedDescription)")
                             completion(accumulatedFoodItems, firstOperationError)
                        } else {
                             completion(accumulatedFoodItems, nil)
                        }
                    }
                case .failure(let error):
                    // Hela query-operationen misslyckades
                    print("CloudKitStore: CKQueryOperation FAILED with error: \(error.localizedDescription)")
                    completion(nil, error) // Skicka tillbaka felet
                }
            }
            
            queryOperation.qualityOfService = .userInitiated // Lämplig QoS för användarinitierad datahämtning
            
            print("CloudKitStore: Adding CKQueryOperation to database...")
            database.add(queryOperation) // Starta operationen
        }

        // Starta den första query-omgången
        performQuery(cursor: nil)
    }
    // *** SLUT ÄNDRING för fetchFoodItems ***


    func subscribeToChanges() {
        let subscriptionID = "fooditem-changes-subscription"
        database.fetch(withSubscriptionID: subscriptionID) { [weak self] existingSubscription, error in
            guard let self = self else { return }

            if existingSubscription != nil {
                print("CloudKitStore: Subscription '\(subscriptionID)' already exists.")
                return
            }

            if let ckError = error as? CKError, ckError.code != .unknownItem {
                 print("CloudKitStore Error: Failed to check for existing subscription '\(subscriptionID)': \(error!.localizedDescription)")
                 return
             }

            print("CloudKitStore: Subscription '\(subscriptionID)' not found, creating...")
            let predicate = NSPredicate(value: true)
            let subscription = CKQuerySubscription(
                recordType: self.foodRecordType,
                predicate: predicate,
                subscriptionID: subscriptionID,
                options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
            )
            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true
            subscription.notificationInfo = notificationInfo

            self.database.save(subscription) { savedSubscription, saveError in
                if let saveError = saveError {
                     if let ckError = saveError as? CKError, ckError.code == .serverRejectedRequest {
                         print("CloudKitStore: Subscription save failed - already exists or server rejected.")
                     } else {
                         print("CloudKitStore Error: Failed to save subscription '\(subscriptionID)': \(saveError.localizedDescription)")
                     }
                } else {
                    print("CloudKitStore: Successfully saved subscription '\(subscriptionID)'.")
                }
            }
        }
    }


     func handleNotification() {
          print("CloudKit notification received, signaling update.")
          foodListNeedsUpdate.send()
      }


    func saveFoodItem(_ foodItem: FoodItem, completion: @escaping (Error?) -> Void) {
         let record = foodItem.toCKRecord()
         print("CloudKitStore: Preparing CKModifyRecordsOperation to save/update record \(record.recordID.recordName)...")

         let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
         
         // ANMÄRKNING: savePolicy .changedKeys fungerar för att uppdatera en befintlig post.
         // Om posten inte finns (nytt foodItem), kommer detta att resultera i ett .unknownItem-fel per post.
         // För en "lägg till eller uppdatera"-logik är .allKeys ofta enklare, men kan skriva över ändringar.
         // Om du vill ha strikt "lägg till om ny, uppdatera om existerar", kan det kräva en check först
         // eller att hantera .unknownItem-felet specifikt. Förutsatt att ditt `FoodData` hanterar
         // om ett item är nytt eller existerande, kan .allKeys vara lämpligt här.
         // Vi behåller .changedKeys enligt din ursprungliga kod, men notera denna begränsning för nya items.
         // Om nya items *alltid* ska skapas, bör savePolicy vara .allKeys och du bör vara medveten om
         // att det skriver över hela posten om ID:t redan existerar.
         // Alternativt, använd .ifServerRecordUnchanged om du har en serverChangeTag,
         // eller .allKeys om du är säker på att du vill skapa eller helt ersätta.
         // Förutsatt att din logik på appnivå skiljer på "add" och "update", kan du ha två olika
         // metoder här eller en parameter för savePolicy.
         // Eftersom problemet verkar ligga i fetch, låter vi save vara tills vidare.
         operation.savePolicy = .changedKeys // Behåller enligt din kod.

         operation.modifyRecordsResultBlock = { result in
             DispatchQueue.main.async {
                 switch result {
                 case .success():
                     print("CloudKitStore: CKModifyRecordsOperation finished successfully for \(record.recordID.recordName).")
                     completion(nil)
                 case .failure(let error):
                     print("CloudKitStore Error: CKModifyRecordsOperation failed for \(record.recordID.recordName): \(error.localizedDescription)")
                      if let ckError = error as? CKError, ckError.code == .serverRecordChanged {
                          print("CloudKitStore Error: Conflict detected (Server Record Changed) for \(record.recordID.recordName).")
                      } else if let ckError = error as? CKError, ckError.code == .unknownItem && operation.savePolicy == .changedKeys {
                          print("CloudKitStore Info: Record \(record.recordID.recordName) not found for update (using .changedKeys). If this was an 'add' operation, .changedKeys might not be appropriate.")
                          // Här skulle man kunna försöka igen med .allKeys om det var ett "add"-försök.
                      }
                     completion(error)
                 }
             }
         }
         operation.qualityOfService = .userInitiated
         print("CloudKitStore: Adding CKModifyRecordsOperation to database for \(record.recordID.recordName)...")
         database.add(operation)
    }

     func deleteFoodItem(withId id: UUID, completion: @escaping (Error?) -> Void) {
          let recordID = CKRecord.ID(recordName: id.uuidString)
          print("CloudKitStore: Preparing CKModifyRecordsOperation to delete record \(recordID.recordName)...")

          let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [recordID])
          operation.modifyRecordsResultBlock = { result in
              DispatchQueue.main.async {
                  switch result {
                  case .success():
                      print("CloudKitStore: CKModifyRecordsOperation finished successfully for deletion of \(recordID.recordName).")
                      completion(nil)
                  case .failure(let error):
                      if let ckError = error as? CKError, ckError.code == .unknownItem {
                          print("CloudKitStore: Record \(recordID.recordName) already deleted or never existed (Delete operation).")
                          completion(nil)
                      } else {
                          print("CloudKitStore Error: CKModifyRecordsOperation failed for deletion of \(recordID.recordName): \(error.localizedDescription)")
                          completion(error)
                      }
                  }
              }
          }
          operation.qualityOfService = .userInitiated
          print("CloudKitStore: Adding CKModifyRecordsOperation to database for deletion of \(recordID.recordName)...")
          database.add(operation)
     }

    func deleteAllFoodItems(recordIDsToDelete: [CKRecord.ID], completion: @escaping (Error?) -> Void) {
        guard !recordIDsToDelete.isEmpty else {
            completion(nil)
            return
        }
        print("CloudKitStore: Preparing CKModifyRecordsOperation to delete \(recordIDsToDelete.count) records...")
        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDsToDelete)
        
        operation.modifyRecordsResultBlock = { result in
            DispatchQueue.main.async {
                switch result {
                case .success():
                    print("CloudKitStore: CKModifyRecordsOperation finished successfully for deletion of all items.")
                    completion(nil)
                case .failure(let error):
                    print("CloudKitStore Error: CKModifyRecordsOperation failed for deletion of all items: \(error.localizedDescription)")
                    completion(error)
                }
            }
        }
        operation.qualityOfService = .userInitiated
        print("CloudKitStore: Adding CKModifyRecordsOperation to database for deletion of all items...")
        database.add(operation)
    }
}

// MARK: - Extensions för konvertering (Oförändrade)
extension FoodItem {
    init?(record: CKRecord) {
        let uuidString = record.recordID.recordName
        guard let name = record["name"] as? String,
              let carbsPer100g = record["carbsPer100g"] as? Double,
              let id = UUID(uuidString: uuidString) else {
            print("Failed to initialize FoodItem from record: \(record.recordID.recordName). Missing required fields (name, carbsPer100g).")
            return nil
        }
         self.id = id
         self.name = name
         self.carbsPer100g = carbsPer100g
         self.grams = 0
         self.gramsPerDl = record["gramsPerDl"] as? Double
         self.styckPerGram = record["styckPerGram"] as? Double
         self.inputUnit = nil
         self.isDefault = false
         self.hasBeenLogged = false
         self.isFavorite = (record["isFavorite"] as? Int64 ?? 0) == 1
         self.isCalculatorItem = false
    }

     func toCKRecord() -> CKRecord {
         let recordID = CKRecord.ID(recordName: self.id.uuidString)
         let record = CKRecord(recordType: CloudKitFoodDataStore.shared.foodRecordType, recordID: recordID)
         record["name"] = self.name as CKRecordValue?
         record["carbsPer100g"] = self.carbsPer100g as CKRecordValue?
         record["gramsPerDl"] = self.gramsPerDl as CKRecordValue?
         record["styckPerGram"] = self.styckPerGram as CKRecordValue?
         record["isFavorite"] = (self.isFavorite ? 1 : 0) as CKRecordValue
         return record
      }
}
