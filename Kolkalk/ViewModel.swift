import Foundation
import WatchConnectivity
import SwiftUI
import UniformTypeIdentifiers

class ViewModel: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = ViewModel()
    @Published var transferStatus: String = ""
    @Published var receivedFoodList: [FoodItem] = []

    override private init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    // Funktion för att skicka CSV-filen till Apple Watch
    func sendCSVFile(fileURL: URL) {
        if WCSession.default.activationState == .activated && WCSession.default.isPaired && WCSession.default.isWatchAppInstalled {
            WCSession.default.transferFile(fileURL, metadata: ["replaceList": true])
            DispatchQueue.main.async {
                self.transferStatus = "CSV-filen skickas till Apple Watch..."
            }
        } else {
            DispatchQueue.main.async {
                self.transferStatus = "Apple Watch är inte tillgänglig."
            }
        }
    }

    // Funktion för att exportera mottagen livsmedelslista till CSV-fil
    func exportFoodListToCSV() {
        let fileName = "exported_food_list.csv"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        var csvText = "Name;CarbsPer100g;GramsPerDl;StyckPerGram\n"

        for food in receivedFoodList {
            let name = food.name
            let carbsPer100g = food.carbsPer100g ?? 0.0
            let gramsPerDl = food.gramsPerDl ?? 0.0
            let styckPerGram = food.styckPerGram ?? 0.0
            let newLine = "\(name);\(carbsPer100g);\(gramsPerDl);\(styckPerGram)\n"
            csvText.append(newLine)
        }

        do {
            try csvText.write(to: path, atomically: true, encoding: .utf8)
            // Presentera delningsbladet
            DispatchQueue.main.async {
                self.shareCSV(url: path)
            }
        } catch {
            print("Misslyckades att skapa fil")
            DispatchQueue.main.async {
                self.transferStatus = "Misslyckades att skapa CSV-fil."
            }
        }
    }

    private func shareCSV(url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activityVC.excludedActivityTypes = [.assignToContact]

        // Hämta den översta visningskontrollern
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true, completion: nil)
        }
    }

    // WCSessionDelegate-metoder
    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                self.transferStatus = "Fel vid överföring: \(error.localizedDescription)"
            } else {
                self.transferStatus = "CSV-filen har skickats!"
            }
        }
    }

    // Mottagning av livsmedelslista från Apple Watch
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            if let foodListData = message["foodList"] as? [[String: Any]] {
                var foodList: [FoodItem] = []
                for foodDict in foodListData {
                    let idString = foodDict["id"] as? String ?? UUID().uuidString
                    let id = UUID(uuidString: idString) ?? UUID()
                    let name = foodDict["name"] as? String ?? ""
                    let carbsPer100g = foodDict["carbsPer100g"] as? Double ?? 0.0
                    let gramsPerDl = foodDict["gramsPerDl"] as? Double
                    let styckPerGram = foodDict["styckPerGram"] as? Double

                    let foodItem = FoodItem(
                        id: id,
                        name: name,
                        carbsPer100g: carbsPer100g,
                        grams: 0.0,
                        gramsPerDl: gramsPerDl,
                        styckPerGram: styckPerGram
                    )
                    foodList.append(foodItem)
                }
                self.receivedFoodList = foodList
                self.transferStatus = "Livsmedelslista mottagen."
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) { }
    func sessionDidDeactivate(_ session: WCSession) { }
    func sessionWatchStateDidChange(_ session: WCSession) { }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.transferStatus = "WCSession aktivering misslyckades: \(error.localizedDescription)"
            }
        } else {
            DispatchQueue.main.async {
                self.transferStatus = "WCSession aktiverad."
            }
        }
    }
}
