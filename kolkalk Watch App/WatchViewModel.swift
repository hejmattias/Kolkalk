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

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WatchViewModel: WCSession activation failed with error: \(error.localizedDescription)")
        } else {
            print("WatchViewModel: WCSession activated with state: \(activationState.rawValue)")
        }
    }

    // Ta bort eller kommentera bort dessa metoder om de finns
    // func sessionDidBecomeInactive(_ session: WCSession) { }

    // func sessionDidDeactivate(_ session: WCSession) {
    //     session.activate()
    // }

    // Om du har andra WCSessionDelegate-metoder, implementera dem här
}

