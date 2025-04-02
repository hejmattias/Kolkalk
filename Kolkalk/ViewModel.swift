// Kolkalk/ViewModel.swift

import Foundation
import WatchConnectivity // Behåll om den används för Container
import SwiftUI
// Ta bort: import UniformTypeIdentifiers (om DocumentPicker flyttats till ContentView)
import os.log

// Säkerställ att WCSessionDelegate finns kvar om du synkar Container via WCSession
class ViewModel: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = ViewModel()
    @Published var transferStatus: String = "" // Kan användas för Container-status

    // Behåll WCSession-initiering om den behövs för Container
    override private init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            print("iOS ViewModel: WCSession activated.")
        } else {
             print("iOS ViewModel: WCSession not supported on this device.")
        }
    }

    // --- WCSessionDelegate METODER (Obligatoriska för iOS) ---

    // Obligatorisk: Anropas när sessionen har aktiverats (eller misslyckats)
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                self.transferStatus = "WCSession aktivering misslyckades: \(error.localizedDescription)"
                print("iOS ViewModel: WCSession activation failed: \(error.localizedDescription)")
            } else {
                self.transferStatus = "WCSession redo (Status: \(activationState.rawValue))."
                print("iOS ViewModel: WCSession activated with state: \(activationState.rawValue)")
                 // Här kan du försöka skicka container-datan direkt om sessionen är aktiv
                 self.sendContainersToWatch(containerData: ContainerData.shared) // Försök skicka vid aktivering
            }
        }
    }

    // Obligatorisk på iOS: Anropas när sessionen blir inaktiv (t.ex. byte av iWatch)
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("iOS ViewModel: WCSession did become inactive.")
        // Kan behöva hanteras om appen ska stödja byte av klocka medan den körs
    }

    // Obligatorisk på iOS: Anropas när sessionen har avaktiverats helt
    func sessionDidDeactivate(_ session: WCSession) {
        print("iOS ViewModel: WCSession did deactivate.")
        // Försök återaktivera sessionen
        WCSession.default.activate()
    }

    // --- Övriga WCSessionDelegate Metoder (Valfria men bra att ha) ---

    // Anropas när Watch State ändras (t.ex. klockan paras/avparas, app installeras/avinstalleras)
    func sessionWatchStateDidChange(_ session: WCSession) {
         print("iOS ViewModel: Watch State Changed - isPaired: \(session.isPaired), isWatchAppInstalled: \(session.isWatchAppInstalled), isReachable: \(session.isReachable)")
         // Uppdatera UI eller logik baserat på klockans status
         // Försök skicka container-data om klockan precis blev nåbar/installerad
         if session.isPaired && session.isWatchAppInstalled {
              self.sendContainersToWatch(containerData: ContainerData.shared)
         }
     }


    // Hantera mottagning av UserInfo (för Container-synkning)
    // Denna behövs fortfarande om du synkar Container på detta sätt.
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
         print("iOS ViewModel: Received user info: \(userInfo.keys)")
         if let data = userInfo["containerList"] as? Data {
             // Försök avkoda och uppdatera ContainerData
             if let containers = try? JSONDecoder().decode([Container].self, from: data) {
                 DispatchQueue.main.async {
                     // Uppdatera den delade instansen (antar att ContainerData är en singleton eller liknande)
                      ContainerData.shared.containerList = containers
                      ContainerData.shared.saveToUserDefaults() // Spara lokalt på iOS också
                      print("iOS ViewModel: Updated container list from Watch UserInfo.")
                 }
             } else {
                 print("iOS ViewModel: Failed to decode container list from Watch UserInfo.")
             }
         }
     }

     // Hantera när överföring av UserInfo är klar (bra för felsökning)
     func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
         DispatchQueue.main.async {
             if let error = error {
                 print("iOS ViewModel: UserInfo transfer failed: \(error.localizedDescription)")
                 self.transferStatus = "Fel vid synkning av kärl: \(error.localizedDescription)"
             } else {
                 // *** KORRIGERING: Ta bort referensen till .transferIdentifier ***
                 print("iOS ViewModel: UserInfo transfer finished successfully.")
                 self.transferStatus = "Kärl synkroniserade." // Uppdatera status vid lyckad överföring
             }
         }
     }


    // --- Din specifika logik ---

    // Behåll funktion för att skicka Container-data om den använder WCSession
    func sendContainersToWatch(containerData: ContainerData) {
        guard WCSession.default.activationState == .activated else {
             print("iOS ViewModel: WCSession not active. Cannot send containers.")
             self.transferStatus = "WCSession ej aktiv."
             return
         }
         guard WCSession.default.isPaired else {
             print("iOS ViewModel: Watch not paired. Cannot send containers.")
             self.transferStatus = "Klocka ej parkopplad."
             return
         }
         guard WCSession.default.isWatchAppInstalled else {
             print("iOS ViewModel: Watch app not installed. Cannot send containers.")
             self.transferStatus = "Klockapp ej installerad."
             return
         }

         do {
             let data = try JSONEncoder().encode(containerData.containerList)
             let userInfo = ["containerList": data]
             // Skicka som UserInfo för att hantera om klockan inte är nåbar direkt
             let transfer = WCSession.default.transferUserInfo(userInfo)
             // *** KORRIGERING: Ta bort referensen till .transferIdentifier ***
             print("iOS ViewModel: Attempting to send containerList via transferUserInfo.")
             self.transferStatus = "Synkroniserar kärl..." // Ge feedback till användaren
         } catch {
             print("iOS ViewModel: Failed to encode container list: \(error.localizedDescription)")
             self.transferStatus = "Fel vid kodning av kärl."
         }
    }
}
