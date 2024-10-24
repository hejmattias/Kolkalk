//
//  HealthKitManager.swift
//  Kolkalk
//
//  Created by Mattias Göransson on 2024-10-24.
//


// Shared/HealthKitManager.swift

import HealthKit

class HealthKitManager {
    static let shared = HealthKitManager()
    let healthStore = HKHealthStore()

    private init() { }

    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        // Define the health data types we want to write
        guard let dietaryCarbohydratesType = HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates) else {
            completion(false, NSError(domain: "HealthKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create dietary carbohydrates type"]))
            return
        }

        let typesToShare: Set = [dietaryCarbohydratesType]

        healthStore.requestAuthorization(toShare: typesToShare, read: nil) { success, error in
            completion(success, error)
        }
    }

    func logCarbohydrates(totalCarbs: Double, metadata: [String: Any]?, completion: @escaping (Bool, Error?) -> Void) {
        guard let dietaryCarbohydratesType = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) else {
            completion(false, NSError(domain: "HealthKit", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to create dietary carbohydrates type"]))
            return
        }

        let quantity = HKQuantity(unit: HKUnit.gram(), doubleValue: totalCarbs)
        let now = Date()
        let sample = HKQuantitySample(type: dietaryCarbohydratesType, quantity: quantity, start: now, end: now, metadata: metadata)

        healthStore.save(sample) { success, error in
            completion(success, error)
        }
    }
}
