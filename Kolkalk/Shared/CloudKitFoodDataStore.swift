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

    // MARK: - Fetch & Subscription (Oförändrade)

    func fetchFoodItems(completion: @escaping ([FoodItem]?, Error?) -> Void) {
        print("CloudKitStore: fetchFoodItems called.")
        let query = CKQuery(recordType: foodRecordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

        print("CloudKitStore: Starting database.fetch operation...")
        database.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
            print("CloudKitStore: database.fetch completion handler started.")
            switch result {
            case .success(let matchResults):
                let recordCount = matchResults.matchResults.count
                print("CloudKitStore: database.fetch SUCCESS. Received \(recordCount) records.")

                let foodItems = matchResults.matchResults.compactMap { recordResult -> FoodItem? in
                    switch recordResult.1 {
                    case .success(let record):
                        return FoodItem(record: record) // Använd init?(record:)
                    case .failure(let error):
                        print("CloudKitStore: Error fetching individual record result: \(error)")
                        return nil
                    }
                }
                print("CloudKitStore: Successfully parsed \(foodItems.count) FoodItems.")
                completion(foodItems, nil)

            case .failure(let error):
                print("CloudKitStore: database.fetch FAILED with error: \(error)")
                completion(nil, error)
            }
        }
    }

    func subscribeToChanges() {
        let subscriptionID = "fooditem-changes-subscription"
        // Kontrollera om prenumerationen redan finns först för att undvika fel
        database.fetch(withSubscriptionID: subscriptionID) { [weak self] existingSubscription, error in
            guard let self = self else { return }

            if existingSubscription != nil {
                print("CloudKitStore: Subscription '\(subscriptionID)' already exists.")
                return // Finns redan, gör inget mer
            }

            // Om prenumerationen inte finns (eller om det blev ett fel annat än 'unknown item')
            if let ckError = error as? CKError, ckError.code != .unknownItem {
                 print("CloudKitStore Error: Failed to check for existing subscription '\(subscriptionID)': \(error!.localizedDescription)")
                 // Fortsätt inte om vi inte kunde verifiera
                 return
             }

            // Skapa prenumerationen eftersom den inte fanns
            print("CloudKitStore: Subscription '\(subscriptionID)' not found, creating...")
            let predicate = NSPredicate(value: true)
            let subscription = CKQuerySubscription(
                recordType: self.foodRecordType,
                predicate: predicate,
                subscriptionID: subscriptionID,
                options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
            )
            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true // För tysta bakgrundsuppdateringar
            subscription.notificationInfo = notificationInfo

            self.database.save(subscription) { savedSubscription, saveError in
                if let saveError = saveError {
                     if let ckError = saveError as? CKError, ckError.code == .serverRejectedRequest {
                         print("CloudKitStore: Subscription save failed - already exists or server rejected.")
                         // Kan hända om två enheter försöker skapa samtidigt
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


    // MARK: - Modification Operations (ÄNDRADE)

    // *** ÄNDRAD: Använder nu CKModifyRecordsOperation ***
    func saveFoodItem(_ foodItem: FoodItem, completion: @escaping (Error?) -> Void) {
         let record = foodItem.toCKRecord() // Konvertera till CKRecord
         print("CloudKitStore: Preparing CKModifyRecordsOperation to save/update record \(record.recordID.recordName)...")

         // Skapa operationen med posten som ska sparas/uppdateras
         let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)

         // Sätt savePolicy. .changedKeys är ofta ett bra val för uppdateringar.
         // Den försöker uppdatera posten om den finns, och skriver bara över de fält
         // som finns i 'record'-objektet. Misslyckas om posten inte finns alls.
         // Om du vill vara ännu säkrare mot att skriva över samtidiga ändringar,
         // överväg .ifServerRecordUnchanged, men det kräver att 'record' är
         // nyligen hämtad från servern (vilket toCKRecord() inte gör).
         operation.savePolicy = .changedKeys

         // Hantera resultatet av hela operationen
         operation.modifyRecordsResultBlock = { result in
             // Gå till huvudtråden för att anropa completion
             DispatchQueue.main.async {
                 switch result {
                 case .success():
                     print("CloudKitStore: CKModifyRecordsOperation finished successfully for \(record.recordID.recordName).")
                     completion(nil) // Ingen fel
                 case .failure(let error):
                     print("CloudKitStore Error: CKModifyRecordsOperation failed for \(record.recordID.recordName): \(error)")
                      // Kontrollera specifikt för "Server Record Changed" igen här om det behövs
                      if let ckError = error as? CKError, ckError.code == .serverRecordChanged {
                          print("CloudKitStore Error: Conflict detected (Server Record Changed) even with CKModifyRecordsOperation. Consider fetching before update or conflict resolution logic.")
                          // Här skulle man kunna implementera mer avancerad konflikthantering
                          // t.ex. hämta båda versionerna och låta användaren välja, eller merge:a.
                      }
                     completion(error) // Skicka tillbaka felet
                 }
             }
         }

         // Sätt Quality of Service (valfritt men bra)
         operation.qualityOfService = .userInitiated // Eftersom det ofta är en direkt användaråtgärd

         print("CloudKitStore: Adding CKModifyRecordsOperation to database for \(record.recordID.recordName)...")
         database.add(operation) // Lägg till operationen i databasens kö
    }

     // *** ÄNDRAD: Använder nu CKModifyRecordsOperation ***
     func deleteFoodItem(withId id: UUID, completion: @escaping (Error?) -> Void) {
          let recordID = CKRecord.ID(recordName: id.uuidString)
          print("CloudKitStore: Preparing CKModifyRecordsOperation to delete record \(recordID.recordName)...")

          // Skapa operationen med ID:t som ska raderas
          let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [recordID])

         // (savePolicy är inte relevant för radering)

          // Hantera resultatet av hela operationen
          operation.modifyRecordsResultBlock = { result in
              // Gå till huvudtråden för att anropa completion
              DispatchQueue.main.async {
                  switch result {
                  case .success():
                      print("CloudKitStore: CKModifyRecordsOperation finished successfully for deletion of \(recordID.recordName).")
                      completion(nil) // Inget fel
                  case .failure(let error):
                      // Kolla om felet är "record not found" - det är ok vid radering
                      if let ckError = error as? CKError, ckError.code == .unknownItem {
                          print("CloudKitStore: Record \(recordID.recordName) already deleted or never existed (Delete operation).")
                          completion(nil) // Inte ett "fel" i detta sammanhang
                      } else {
                          print("CloudKitStore Error: CKModifyRecordsOperation failed for deletion of \(recordID.recordName): \(error)")
                          completion(error) // Skicka tillbaka andra fel
                      }
                  }
              }
          }

          // Sätt Quality of Service
          operation.qualityOfService = .userInitiated

          print("CloudKitStore: Adding CKModifyRecordsOperation to database for deletion of \(recordID.recordName)...")
          database.add(operation) // Lägg till operationen i databasens kö
     }

    // Radera alla (kan också använda CKModifyRecordsOperation, men var redan så)
    func deleteAllFoodItems(recordIDsToDelete: [CKRecord.ID], completion: @escaping (Error?) -> Void) {
        guard !recordIDsToDelete.isEmpty else {
            completion(nil)
            return
        }
        print("CloudKitStore: Preparing CKModifyRecordsOperation to delete \(recordIDsToDelete.count) records...")
        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDsToDelete)
        operation.savePolicy = .allKeys // Irrelevant för delete, men måste sättas

        operation.modifyRecordsResultBlock = { result in
            DispatchQueue.main.async {
                switch result {
                case .success():
                    print("CloudKitStore: CKModifyRecordsOperation finished successfully for deletion of all items.")
                    completion(nil)
                case .failure(let error):
                    print("CloudKitStore Error: CKModifyRecordsOperation failed for deletion of all items: \(error)")
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
    // Konvertera från CKRecord till FoodItem
    init?(record: CKRecord) {
        let uuidString = record.recordID.recordName
        // Säkerställ att alla *nödvändiga* fält finns
        guard let name = record["name"] as? String,
              let carbsPer100g = record["carbsPer100g"] as? Double,
              let id = UUID(uuidString: uuidString) else {
            print("Failed to initialize FoodItem from record: \(record.recordID.recordName). Missing required fields (name, carbsPer100g).")
            return nil
        }
         self.id = id
         self.name = name
         self.carbsPer100g = carbsPer100g

         // Sätt standardvärden eller hämta valfria fält
         self.grams = 0 // Gram sparas inte i CloudKit-listan
         self.gramsPerDl = record["gramsPerDl"] as? Double
         self.styckPerGram = record["styckPerGram"] as? Double
         self.inputUnit = nil // Sparas inte i CloudKit-listan
         self.isDefault = false // Sparas inte i CloudKit-listan
         self.hasBeenLogged = false // Sparas inte i CloudKit-listan
         // Hämta favoritstatus (sparas som Int64 i exemplet)
         self.isFavorite = (record["isFavorite"] as? Int64 ?? 0) == 1
         self.isCalculatorItem = false // Sparas inte i CloudKit-listan
    }

    // Konvertera från FoodItem till CKRecord
     func toCKRecord() -> CKRecord {
         let recordID = CKRecord.ID(recordName: self.id.uuidString)
         // Skapa en ny record eller hämta en befintlig om du har changeTag?
         // För denna funktion skapar vi alltid en ny för enkelhetens skull.
         let record = CKRecord(recordType: CloudKitFoodDataStore.shared.foodRecordType, recordID: recordID)

         // Sätt värdena som ska sparas till CloudKit
         record["name"] = self.name as CKRecordValue? // Obligatorisk
         record["carbsPer100g"] = self.carbsPer100g as CKRecordValue? // Obligatorisk
         // Sätt valfria värden endast om de inte är nil
         record["gramsPerDl"] = self.gramsPerDl as CKRecordValue?
         record["styckPerGram"] = self.styckPerGram as CKRecordValue?
         // Konvertera Bool till Int64 (0 eller 1) för CloudKit-kompatibilitet
         record["isFavorite"] = (self.isFavorite ? 1 : 0) as CKRecordValue

         // Fält som inte sparas i CloudKit (grams, inputUnit, etc.) inkluderas inte.

         return record
      }
}
