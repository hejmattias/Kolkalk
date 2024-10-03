import Foundation
import WatchConnectivity

class WatchViewModel: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchViewModel()
    @Published var foodData = FoodData()

    override private init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // Funktion för att exportera livsmedelslistan till iOS-appen
    func exportFoodList() {
        if WCSession.default.isReachable {
            // Konvertera livsmedelslistan till ett format som kan skickas
            let foodListData = foodData.foodList.map { foodItem -> [String: Any] in
                return [
                    "id": foodItem.id.uuidString,
                    "name": foodItem.name,
                    "carbsPer100g": foodItem.carbsPer100g ?? 0.0,
                    "gramsPerDl": foodItem.gramsPerDl ?? 0.0,
                    "styckPerGram": foodItem.styckPerGram ?? 0.0
                ]
            }
            let message = ["foodList": foodListData]
            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                print("Fel vid skickande av livsmedelslista: \(error.localizedDescription)")
            }
        } else {
            print("iOS-appen är inte nåbar")
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

    // WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) { }

    // Andra nödvändiga WCSessionDelegate-metoder
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // Hantera inkommande meddelanden om det behövs
    }
}
