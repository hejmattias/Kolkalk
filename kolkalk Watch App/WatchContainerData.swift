// kolkalk Watch App/WatchContainerData.swift

import Foundation
import WatchConnectivity

class WatchContainerData: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchContainerData()
    @Published var containerList: [Container] = []

    private override init() {
        super.init()
        loadFromUserDefaults()

        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func loadFromUserDefaults() {
        if let data = UserDefaults.standard.data(forKey: "containerList"),
           let savedContainers = try? JSONDecoder().decode([Container].self, from: data) {
            containerList = savedContainers
        } else {
            // Ladda standardkärl om ingen sparad data finns
            containerList = [
                Container(name: "Litet glas", weight: 50.0),
                Container(name: "Måttkopp", weight: 100.0),
                Container(name: "Stor skål", weight: 200.0),
            ]
        }
    }

    func saveToUserDefaults() {
        if let data = try? JSONEncoder().encode(containerList) {
            UserDefaults.standard.set(data, forKey: "containerList")
        }
    }

    // MARK: - WCSessionDelegate-metoder

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        if let data = userInfo["containerList"] as? Data {
            if let containers = try? JSONDecoder().decode([Container].self, from: data) {
                DispatchQueue.main.async {
                    self.containerList = containers
                    self.saveToUserDefaults()
                }
            }
        }
    }

    // Ta bort dessa metoder eftersom de är otillgängliga i nyare versioner av watchOS
    /*
    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    */
}
