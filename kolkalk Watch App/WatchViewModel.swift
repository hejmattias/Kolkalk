// Kolkalk.zip/kolkalk Watch App/WatchViewModel.swift

import Foundation
import WatchConnectivity // Behåll om den behövs för Container
import SwiftUI
import os.log

class WatchViewModel: NSObject, ObservableObject, WCSessionDelegate { // Behåll WCSessionDelegate om Container
    static let shared = WatchViewModel()
    // FoodData hämtas nu direkt i vyerna eller via @StateObject där det behövs
    // Ta bort: @Published var foodData = FoodData()
    @ObservedObject var containerData = WatchContainerData.shared // Behåll Container

    override private init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            print("WatchViewModel: WCSession activated (for Container sync if needed).")
        }
    }

    // Behåll didReceiveUserInfo om Container skickas så
     func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
         print("WatchViewModel: Received user info: \(userInfo.keys)")
         if let data = userInfo["containerList"] as? Data {
             if let containers = try? JSONDecoder().decode([Container].self, from: data) {
                 DispatchQueue.main.async {
                     // Uppdatera containerData direkt här
                     WatchContainerData.shared.containerList = containers
                     WatchContainerData.shared.saveToUserDefaults() // Spara lokalt på klockan
                     print("WatchViewModel: Updated container list with received data.")
                 }
             } else {
                 print("WatchViewModel: Failed to decode container list.")
             }
         }
     }

    // --- Ta bort metoder relaterade till livsmedelsöverföring ---
    // func session(_ session: WCSession, didReceive file: WCSessionFile) { ... }
    // func getDocumentsDirectory() -> URL { ... } // Om den bara användes för CSV

    // --- Behåll WCSessionDelegate-metoder ---
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WatchViewModel: WCSession activation failed with error: \(error.localizedDescription)")
        } else {
            print("WatchViewModel: WCSession activated with state: \(activationState.rawValue)")
        }
    }

    // Implementera övriga WCSessionDelegate-metoder vid behov
}
