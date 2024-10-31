// Shared/HealthKitManager.swift

import HealthKit

class HealthKitManager {
    static let shared = HealthKitManager()
    let healthStore = HKHealthStore()

    private init() { }

    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        // Definiera hälsodatatyper vi vill skriva och läsa
        guard let dietaryCarbohydratesType = HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates),
              let insulinDeliveryType = HKObjectType.quantityType(forIdentifier: .insulinDelivery) else {
            completion(false, NSError(domain: "HealthKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Kunde inte skapa hälsodatatyper"]))
            return
        }

        let typesToShare: Set = [dietaryCarbohydratesType, insulinDeliveryType]
        let typesToRead: Set = [dietaryCarbohydratesType, insulinDeliveryType]

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            completion(success, error)
        }
    }

    func logCarbohydrates(totalCarbs: Double, metadata: [String: Any]?, completion: @escaping (Bool, Error?) -> Void) {
        guard let dietaryCarbohydratesType = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) else {
            completion(false, NSError(domain: "HealthKit", code: 2, userInfo: [NSLocalizedDescriptionKey: "Kunde inte skapa dietary carbohydrates type"]))
            return
        }

        let quantity = HKQuantity(unit: HKUnit.gram(), doubleValue: totalCarbs)
        let now = Date()
        let sample = HKQuantitySample(type: dietaryCarbohydratesType, quantity: quantity, start: now, end: now, metadata: metadata)

        healthStore.save(sample) { success, error in
            completion(success, error)
        }
    }

    // MARK: - Ny funktion för att logga insulin

    func logInsulinDose(dose: Double, insulinType: HKInsulinDeliveryReason, completion: @escaping (Bool, Error?) -> Void) {
        guard let insulinDeliveryType = HKQuantityType.quantityType(forIdentifier: .insulinDelivery) else {
            completion(false, NSError(domain: "HealthKit", code: 3, userInfo: [NSLocalizedDescriptionKey: "Kunde inte skapa insulin delivery type"]))
            return
        }

        let unit = HKUnit.internationalUnit()
        let quantity = HKQuantity(unit: unit, doubleValue: dose)
        let now = Date()
        let metadata: [String: Any] = [
            HKMetadataKeyInsulinDeliveryReason: insulinType.rawValue
        ]

        let sample = HKQuantitySample(type: insulinDeliveryType, quantity: quantity, start: now, end: now, metadata: metadata)

        healthStore.save(sample) { success, error in
            completion(success, error)
        }
    }
}
