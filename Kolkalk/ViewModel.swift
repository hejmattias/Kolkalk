// Kolkalk/ViewModel.swift

import Foundation
// Ta bort WatchConnectivity om det inte används alls längre
// import WatchConnectivity
import SwiftUI
import os.log

// Om WCSession inte behövs alls: class ViewModel: NSObject, ObservableObject {
// Om den KANSKE behövs för annat: class ViewModel: NSObject, ObservableObject, WCSessionDelegate {
class ViewModel: NSObject, ObservableObject { // Ta bort WCSessionDelegate om onödigt
    static let shared = ViewModel()
    // Ta bort transferStatus om WCSession tas bort
    // @Published var transferStatus: String = ""

    override private init() {
        super.init()
        // Ta bort WCSession-aktivering om onödigt
        /*
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self // Kräver WCSessionDelegate ovan
            session.activate()
            print("iOS ViewModel: WCSession activated (If needed).")
        } else {
             print("iOS ViewModel: WCSession not supported on this device.")
        }
        */
        print("iOS ViewModel initialized (WCSession removed/commented).")
    }

    // --- Ta bort alla WCSessionDelegate-metoder ---
    /*
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) { ... }
    func sessionDidBecomeInactive(_ session: WCSession) { ... }
    func sessionDidDeactivate(_ session: WCSession) { ... }
    func sessionWatchStateDidChange(_ session: WCSession) { ... }
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) { ... }
     func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) { ... }
    */

    // --- Ta bort den gamla funktionen för att skicka kärl ---
    // func sendContainersToWatch(containerData: ContainerData) { ... }
}
