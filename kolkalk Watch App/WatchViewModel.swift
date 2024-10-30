import Foundation
import WatchConnectivity
import SwiftUI
import os.log

class WatchViewModel: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchViewModel()
    @Published var foodData = FoodData()
    @Published var containerData = WatchContainerData.shared

    override private init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    // Funktion för att exportera livsmedelslistan till iOS-appen inklusive isFavorite
    func exportFoodList() {
        let foodListData = self.foodData.foodList.map { foodItem -> [String: Any] in
            return [
                "id": foodItem.id.uuidString,
                "name": foodItem.name,
                "carbsPer100g": foodItem.carbsPer100g ?? 0.0,
                "gramsPerDl": foodItem.gramsPerDl ?? 0.0,
                "styckPerGram": foodItem.styckPerGram ?? 0.0,
                "isFavorite": foodItem.isFavorite // Inkludera isFavorite
            ]
        }
        let message = ["foodList": foodListData]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: { error in
                os_log("Watch: Error sending food list: %@", error.localizedDescription)
            })
            os_log("Watch: Sent food list to iOS via sendMessage")
        } else {
            os_log("Watch: iOS is not reachable")
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            os_log("WCSession aktivering misslyckades: %@", error.localizedDescription)
        } else {
            os_log("WCSession aktiverad med state: %d", activationState.rawValue)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        DispatchQueue.main.async {
            os_log("Watch: Received message: %@", message)
            if let requestFoodList = message["requestFoodList"] as? Bool, requestFoodList {
                os_log("Watch: Received request for food list via sendMessage")
                let foodListData = self.foodData.foodList.map { foodItem -> [String: Any] in
                    return [
                        "id": foodItem.id.uuidString,
                        "name": foodItem.name,
                        "carbsPer100g": foodItem.carbsPer100g ?? 0.0,
                        "gramsPerDl": foodItem.gramsPerDl ?? 0.0,
                        "styckPerGram": foodItem.styckPerGram ?? 0.0,
                        "isFavorite": foodItem.isFavorite // Inkludera isFavorite
                    ]
                }
                let response = ["foodList": foodListData]
                replyHandler(response)
                os_log("Watch: Sent food list to iOS via replyHandler")
            }
        }
    }

    // Mottagning av filer
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let destinationURL = getDocumentsDirectory().appendingPathComponent("food_items.csv")

        do {
            // Ta bort eventuell tidigare fil
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: file.fileURL, to: destinationURL)
            DispatchQueue.main.async {
                self.foodData.importFromCSV(fileURL: destinationURL)
            }
        } catch {
            print("Fel vid kopiering av fil: \(error)")
        }
    }

    func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // Om du behöver implementera andra delegate-metoder, lägg till dem här
}

