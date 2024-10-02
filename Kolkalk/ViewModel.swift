// ViewModel.swift
import Foundation
import WatchConnectivity
import SwiftUI
import UniformTypeIdentifiers

class ViewModel: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = ViewModel()
    @Published var transferStatus: String = ""
    
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
