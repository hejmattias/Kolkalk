//
//  CloudKitContainerDataStore.swift
//  Kolkalk
//
//  Created by Mattias Göransson on 2025-04-02.
//


// Shared/CloudKitContainerDataStore.swift

import Foundation
import CloudKit
import Combine

/// Hanterar all interaktion med CloudKit för Container-objekt.
class CloudKitContainerDataStore {
    static let shared = CloudKitContainerDataStore()

    // Använd samma CKContainer som för livsmedel
    let container: CKContainer
    lazy var database = container.privateCloudDatabase
    let containerRecordType = "ContainerRecord" // Nytt namn för kärl-poster

    // Signal för att meddela när kärllistan behöver uppdateras
    let containerListNeedsUpdate = PassthroughSubject<Void, Never>()

    private init() {
        // Återanvänd container-identifieraren
        let containerIdentifier = "iCloud.MG.kolkylator"
        container = CKContainer(identifier: containerIdentifier)
        print("CloudKitContainerDataStore initialized using container: \(containerIdentifier)")

        // Prenumerera på ändringar för den nya recordTypen
        subscribeToChanges()
    }

    // MARK: - CRUD Operations for Containers

    /// Hämtar alla Container-poster från CloudKit.
    func fetchContainers(completion: @escaping ([Container]?, Error?) -> Void) {
        print("CloudKitContainerStore: fetchContainers called.")
        let query = CKQuery(recordType: containerRecordType, predicate: NSPredicate(value: true))
        // Sortera efter namn som standard
        query.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

        print("CloudKitContainerStore: Starting database.fetch operation...")
        database.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
            print("CloudKitContainerStore: database.fetch completion handler started.")
            switch result {
            case .success(let matchResults):
                let recordCount = matchResults.matchResults.count
                print("CloudKitContainerStore: database.fetch SUCCESS. Received \(recordCount) records.")

                // Konvertera CKRecord till Container asynkront? Kan vara många bilder.
                // För enkelhetens skull gör vi det här, men för stora bilder kan det blockera.
                let containers = matchResults.matchResults.compactMap { recordResult -> Container? in
                    switch recordResult.1 {
                    case .success(let record):
                        if let item = Container(record: record) {
                            return item
                        } else {
                            print("CloudKitContainerStore: Failed to parse record \(record.recordID.recordName)")
                            return nil
                        }
                    case .failure(let error):
                        print("CloudKitContainerStore: Error fetching individual record result: \(error)")
                        return nil
                    }
                }
                print("CloudKitContainerStore: Successfully parsed \(containers.count) Containers.")
                completion(containers, nil)

            case .failure(let error):
                print("CloudKitContainerStore: database.fetch FAILED with error: \(error)")
                completion(nil, error)
            }
        }
    }

    /// Sparar eller uppdaterar ett Container-objekt i CloudKit.
    func saveContainer(_ container: Container, completion: @escaping (Error?) -> Void) {
         let record = container.toCKRecord()
         print("CloudKitContainerStore: Saving record \(record.recordID.recordName)...")
         database.save(record) { savedRecord, error in
             if let error = error {
                 print("CloudKitContainerStore Error: Failed to save container \(container.id): \(error)")
             } else {
                print("CloudKitContainerStore: Successfully saved container \(container.id).")
             }
            // Ta bort temporär fil för CKAsset efter att save är klar (eller misslyckats)
             if let asset = record["image"] as? CKAsset, let tempURL = asset.fileURL {
                // print("Attempting to remove temp asset file: \(tempURL.path)")
                try? FileManager.default.removeItem(at: tempURL)
             }
             completion(error)
         }
    }

    /// Raderar ett Container-objekt från CloudKit baserat på ID.
     func deleteContainer(withId id: UUID, completion: @escaping (Error?) -> Void) {
          let recordID = CKRecord.ID(recordName: id.uuidString)
          print("CloudKitContainerStore: Deleting record \(recordID.recordName)...")
          database.delete(withRecordID: recordID) { deletedRecordID, error in
              if let error = error {
                  print("CloudKitContainerStore Error: Failed to delete container with id \(id): \(error)")
              } else {
                   print("CloudKitContainerStore: Successfully deleted container \(id).")
              }
              completion(error)
          }
     }

    /// Skapar eller uppdaterar en prenumeration för ändringar i Container-poster.
     func subscribeToChanges() {
          let subscriptionID = "container-changes-subscription" // Unikt ID för denna prenumeration
          let predicate = NSPredicate(value: true) // Lyssna på alla ändringar
          let subscription = CKQuerySubscription(
              recordType: containerRecordType, // Lyssna på ContainerRecord
              predicate: predicate,
              subscriptionID: subscriptionID,
              options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
          )
           let notificationInfo = CKSubscription.NotificationInfo()
           // Viktigt för tysta uppdateringar i bakgrunden
           notificationInfo.shouldSendContentAvailable = true
           subscription.notificationInfo = notificationInfo

            // Kontrollera om prenumerationen redan finns först
           database.fetch(withSubscriptionID: subscriptionID) { [weak self] existingSubscription, error in
               guard let self = self else { return }
               if existingSubscription != nil {
                   print("CloudKitContainerStore: Subscription '\(subscriptionID)' already exists.")
                   // Man kan uppdatera prenumerationen här om nödvändigt, men oftast inte.
               } else {
                   // Prenumerationen finns inte, spara den
                   print("CloudKitContainerStore: Subscription '\(subscriptionID)' not found, attempting to save...")
                   self.database.save(subscription) { savedSubscription, saveError in
                       if let saveError = saveError {
                            if let ckError = saveError as? CKError, ckError.code == .serverRejectedRequest {
                               print("CloudKitContainerStore: Subscription save failed - already exists or server rejected.")
                           } else if let ckError = saveError as? CKError, ckError.code == .notAuthenticated {
                                print("CloudKitContainerStore Error: Cannot save subscription, user not authenticated.")
                           }
                           else {
                               print("CloudKitContainerStore Error: Failed to save subscription '\(subscriptionID)': \(saveError.localizedDescription)")
                           }
                       } else {
                           print("CloudKitContainerStore: Successfully saved subscription '\(subscriptionID)'.")
                       }
                   }
               }
               if let fetchError = error as? CKError, fetchError.code != .unknownItem {
                   // Logga andra fel än "hittades inte" vid hämtningsförsöket
                    print("CloudKitContainerStore Error: Failed to fetch subscription '\(subscriptionID)': \(fetchError.localizedDescription)")
               }
           }
     }

    /// Anropas när en push-notis för kärl tas emot, skickar en signal om att uppdatera.
      func handleContainerNotification() {
           print("CloudKitContainerStore: Container notification received, signaling update.")
           containerListNeedsUpdate.send()
       }
}