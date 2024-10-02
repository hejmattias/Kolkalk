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
}
