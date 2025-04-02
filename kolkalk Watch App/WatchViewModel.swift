// Kolkalk.zip/kolkalk Watch App/WatchViewModel.swift

import Foundation
// Ta bort WatchConnectivity om det inte används alls längre
// import WatchConnectivity
import SwiftUI
import os.log

// Om WCSession inte behövs alls: class WatchViewModel: NSObject, ObservableObject {
// Om den KANSKE behövs för annat: class WatchViewModel: NSObject, ObservableObject, WCSessionDelegate {
class WatchViewModel: NSObject, ObservableObject { // Ta bort WCSessionDelegate om onödigt
    static let shared = WatchViewModel()
    // Ta bort referens till containerData om den inte behövs här längre
    // @ObservedObject var containerData = WatchContainerData.shared

    override private init() {
        super.init()
        // Ta bort WCSession-aktivering om onödigt
        /*
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self // Kräver WCSessionDelegate ovan
            session.activate()
            print("WatchViewModel: WCSession activated (If needed).")
        }
        */
         print("WatchViewModel initialized (WCSession removed/commented).")
    }

    // --- Ta bort WCSessionDelegate-metoder ---
    /*
     func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) { ... } // Ta bort om bara för kärl
     func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) { ... }
    // Implementera övriga WCSessionDelegate-metoder vid behov
    */
}
