// Kolkalk.zip/kolkalk Watch App/FoodData.swift

import SwiftUI
import Foundation
import Combine
import CloudKit // Importera CloudKit

// FoodData-klassen som hanterar listan av livsmedel
class FoodData: ObservableObject {
    @Published var foodList: [FoodItem] = []
    private var cancellables = Set<AnyCancellable>() // För Combine-prenumerationer

    init() {
        print("FoodData [Watch]: init called.") // Se att init körs

        // Lyssna på uppdateringssignaler från CloudKitDataStore
        CloudKitFoodDataStore.shared.foodListNeedsUpdate
            .sink { [weak self] in
                print("FoodData [Watch]: Received update signal. Fetching...")
                self?.loadFoodList() // Ladda om listan när en ändring sker
            }
            .store(in: &cancellables)

        // Ladda listan initialt
        print("FoodData [Watch]: Calling loadFoodList from init.")
        loadFoodList()
    }

    // Ladda om listan från CloudKit
    func loadFoodList() {
        print("FoodData [Watch]: loadFoodList called. Fetching from CloudKit...")
        CloudKitFoodDataStore.shared.fetchFoodItems { [weak self] (items, error) in
            // Logga direkt när completion körs, INNAN main queue
            print("FoodData [Watch]: fetchFoodItems completion handler started.")
            if let error = error {
                print("FoodData [Watch]: Error received in loadFoodList completion: \(error)")
                // Töm listan vid fel för att undvika att visa gammal data?
                 DispatchQueue.main.async {
                    self?.foodList = []
                 }
                return
            }

            let receivedCount = items?.count ?? 0
            print("FoodData [Watch]: fetchFoodItems completion successful. Received \(receivedCount) items. Dispatching to main thread...")

            DispatchQueue.main.async {
                guard let self = self else {
                    print("FoodData [Watch]: self is nil in main thread dispatch.")
                    return
                }
                print("FoodData [Watch]: Updating @Published foodList on main thread.")
                self.foodList = items ?? []
                print("FoodData [Watch]: @Published foodList updated. New count: \(self.foodList.count)")
            }
        }
    }

    // Lägg till ett nytt livsmedel via CloudKit
    func addFoodItem(_ foodItem: FoodItem) {
        CloudKitFoodDataStore.shared.saveFoodItem(foodItem) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error adding food item in Watch App: \(error)")
                } else {
                    if !(self?.foodList.contains(where: { $0.id == foodItem.id }) ?? false) {
                         self?.foodList.append(foodItem)
                         self?.sortFoodList()
                    }
                    print("Watch FoodData added item (locally). CloudKit save initiated.")
                }
            }
        }
    }

    // Uppdatera ett livsmedel via CloudKit
    func updateFoodItem(_ foodItem: FoodItem) {
         CloudKitFoodDataStore.shared.saveFoodItem(foodItem) { [weak self] error in
             DispatchQueue.main.async {
                 if let error = error {
                     print("Error updating food item in Watch App: \(error)")
                 } else {
                     if let index = self?.foodList.firstIndex(where: { $0.id == foodItem.id }) {
                         self?.foodList[index] = foodItem
                         self?.sortFoodList()
                     }
                     print("Watch FoodData updated item (locally). CloudKit save initiated.")
                 }
             }
         }
     }

    // Radera ett livsmedel via CloudKit
     func deleteFoodItem(withId id: UUID) {
         CloudKitFoodDataStore.shared.deleteFoodItem(withId: id) { [weak self] error in
             DispatchQueue.main.async {
                 if let error = error {
                     print("Error deleting food item in Watch App: \(error)")
                 } else {
                     self?.foodList.removeAll { $0.id == id }
                     print("Watch FoodData deleted item (locally). CloudKit delete initiated.")
                 }
             }
         }
     }

     // Radera alla via CloudKit
     func deleteAllFoodItems() {
        let itemsToDelete = foodList
        guard !itemsToDelete.isEmpty else { return }
        let recordIDsToDelete = itemsToDelete.map { CKRecord.ID(recordName: $0.id.uuidString) }
        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDsToDelete)
        operation.savePolicy = .changedKeys
        operation.modifyRecordsResultBlock = { [weak self] result in
             DispatchQueue.main.async {
                 switch result {
                 case .success():
                     print("Successfully deleted all food items from CloudKit.")
                     self?.foodList.removeAll()
                 case .failure(let error):
                     print("Error deleting all food items from CloudKit: \(error)")
                     self?.loadFoodList() // Ladda om vid fel
                 }
             }
         }
        CloudKitFoodDataStore.shared.database.add(operation)
     }


    // Funktion för att sortera foodList i bokstavsordning
    private func sortFoodList() {
        foodList.sort { $0.name.lowercased() < $1.name.lowercased() }
    }
}
