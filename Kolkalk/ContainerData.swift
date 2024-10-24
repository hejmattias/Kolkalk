// Kolkalk/ContainerData.swift

import Foundation
import SwiftUI
import WatchConnectivity

class ContainerData: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = ContainerData()
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

    func addContainer(_ container: Container) {
        containerList.append(container)
        saveToUserDefaults()
        sendContainersToWatch()
    }

    func updateContainer(_ container: Container) {
        if let index = containerList.firstIndex(where: { $0.id == container.id }) {
            containerList[index] = container
            saveToUserDefaults()
            sendContainersToWatch()
        }
    }

    func deleteContainer(_ container: Container) {
        if let index = containerList.firstIndex(where: { $0.id == container.id }) {
            containerList.remove(at: index)
            saveToUserDefaults()
            sendContainersToWatch()
        }
    }

    func saveToUserDefaults() {
        if let data = try? JSONEncoder().encode(containerList) {
            UserDefaults.standard.set(data, forKey: "containerList")
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

    func sendContainersToWatch() {
        if WCSession.default.isPaired && WCSession.default.isWatchAppInstalled {
            do {
                let data = try JSONEncoder().encode(containerList)
                let message = ["containerList": data]
                WCSession.default.transferUserInfo(message)
            } catch {
                print("Misslyckades att koda kärllistan: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - WCSessionDelegate-metoder

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        // Hantera inkommande data från Apple Watch om det behövs
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
