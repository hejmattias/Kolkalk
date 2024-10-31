import Foundation
import SwiftUI

class WatchContainerData: ObservableObject {
    static let shared = WatchContainerData()
    @Published var containerList: [Container] = []

    private init() {
        loadFromUserDefaults()
        // Ta bort WCSession-konfigurationen härifrån
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

    // Ta bort WCSessionDelegate-konformitet och metoder
}

