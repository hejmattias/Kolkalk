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
            print("WatchViewModel: WCSession activated")
        }
    }

    // Implementera session(_:didReceiveUserInfo:)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        print("WatchViewModel: Received user info: \(userInfo)")

        // Hantera mottagen containerList
        if let data = userInfo["containerList"] as? Data {
            if let containers = try? JSONDecoder().decode([Container].self, from: data) {
                DispatchQueue.main.async {
                    self.containerData.containerList = containers
                    self.containerData.saveToUserDefaults()
                    print("WatchViewModel: Updated container list with received data.")
                }
            } else {
                print("WatchViewModel: Failed to decode container list.")
            }
        }

        // Hantera annan inkommande data om det behövs
    }

    // Implementera session(_:didReceiveFile:)
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        print("WatchViewModel: Received file: \(file.fileURL)")

        // Hantera mottagen CSV-fil
        let destinationURL = getDocumentsDirectory().appendingPathComponent("food_items.csv")

        do {
            // Ta bort eventuell tidigare fil
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: file.fileURL, to: destinationURL)
            DispatchQueue.main.async {
                self.foodData.importFromCSV(fileURL: destinationURL)
                print("WatchViewModel: Imported food items from CSV.")
            }
        } catch {
            print("WatchViewModel: Error copying file: \(error.localizedDescription)")
        }
    }

    // Hjälpmetod för att få Documents Directory
    func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WatchViewModel: WCSession activation failed with error: \(error.localizedDescription)")
        } else {
            print("WatchViewModel: WCSession activated with state: \(activationState.rawValue)")
        }
    }

    // Om du har andra WCSessionDelegate-metoder, implementera dem här
}
