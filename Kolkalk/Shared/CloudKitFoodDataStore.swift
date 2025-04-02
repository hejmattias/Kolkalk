// Kolkalk/Shared/CloudKitFoodDataStore.swift

import Foundation
import CloudKit
import Combine

class CloudKitFoodDataStore {
    static let shared = CloudKitFoodDataStore()

    // Använd explicit ID som fungerade
    let container: CKContainer
    lazy var database = container.privateCloudDatabase
    let foodRecordType = "FoodItemRecord"

    let foodListNeedsUpdate = PassthroughSubject<Void, Never>()

    private init() {
        let containerIdentifier = "iCloud.MG.kolkylator" // <<< Ditt fungerande ID
        container = CKContainer(identifier: containerIdentifier)
        print("CloudKitFoodDataStore initialized. Explicitly using container: \(containerIdentifier)")

        subscribeToChanges()
    }

    // MARK: - CRUD Operations

    func fetchFoodItems(completion: @escaping ([FoodItem]?, Error?) -> Void) {
        print("CloudKitStore: fetchFoodItems called.") // Loggning
        let query = CKQuery(recordType: foodRecordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

        print("CloudKitStore: Starting database.fetch operation...") // Loggning
        database.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
            print("CloudKitStore: database.fetch completion handler started.") // Loggning
            switch result {
            case .success(let matchResults):
                let recordCount = matchResults.matchResults.count
                print("CloudKitStore: database.fetch SUCCESS. Received \(recordCount) records.") // Loggning

                let foodItems = matchResults.matchResults.compactMap { recordResult -> FoodItem? in
                    switch recordResult.1 {
                    case .success(let record):
                        if let item = FoodItem(record: record) {
                            return item
                        } else {
                            print("CloudKitStore: Failed to parse record \(record.recordID.recordName)") // Loggning
                            return nil
                        }
                    case .failure(let error):
                        print("CloudKitStore: Error fetching individual record result: \(error)") // Loggning
                        return nil
                    }
                }
                print("CloudKitStore: Successfully parsed \(foodItems.count) FoodItems.") // Loggning
                completion(foodItems, nil)

            case .failure(let error):
                print("CloudKitStore: database.fetch FAILED with error: \(error)") // Loggning
                completion(nil, error)
            }
        }
    }

    // saveFoodItem, deleteFoodItem, subscribeToChanges, handleNotification...
    // (Inga ändringar i dessa funktioners logik, men loggningen vi lade till finns kvar)
    func saveFoodItem(_ foodItem: FoodItem, completion: @escaping (Error?) -> Void) {
         let record = foodItem.toCKRecord()
         database.save(record) { savedRecord, error in
             if let error = error {
                 print("Error saving food item: \(error)")
             }
             completion(error)
         }
    }

     func deleteFoodItem(withId id: UUID, completion: @escaping (Error?) -> Void) {
          let recordID = CKRecord.ID(recordName: id.uuidString)
          database.delete(withRecordID: recordID) { deletedRecordID, error in
              if let error = error {
                  print("Error deleting food item with id \(id): \(error)")
              }
              completion(error)
          }
     }

     func subscribeToChanges() {
          let subscriptionID = "fooditem-changes-subscription"
          let predicate = NSPredicate(value: true)
          let subscription = CKQuerySubscription(
              recordType: foodRecordType,
              predicate: predicate,
              subscriptionID: subscriptionID,
              options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
          )
           let notificationInfo = CKSubscription.NotificationInfo()
           notificationInfo.shouldSendContentAvailable = true
           subscription.notificationInfo = notificationInfo

           database.save(subscription) { savedSubscription, error in
               if let error = error {
                   if let ckError = error as? CKError, ckError.code == .serverRejectedRequest {
                        print("Subscription already exists or other server rejection.")
                    } else {
                        print("Failed to save subscription: \(error.localizedDescription)")
                    }
               } else {
                   print("Successfully subscribed to FoodItem changes.")
               }
           }
     }

      func handleNotification() {
           print("CloudKit notification received, signaling update.")
           foodListNeedsUpdate.send()
       }
}

// MARK: - Extensions för konvertering mellan FoodItem och CKRecord
extension FoodItem {
   // ... (init?(record:) och toCKRecord() är oförändrade) ...
    init?(record: CKRecord) {
        let uuidString = record.recordID.recordName
        guard let name = record["name"] as? String,
              let carbsPer100g = record["carbsPer100g"] as? Double,
              let id = UUID(uuidString: uuidString) else {
            print("Failed to initialize FoodItem from record: \(record.recordID.recordName). Missing required fields.")
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
