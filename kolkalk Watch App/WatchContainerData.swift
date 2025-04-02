// kolkalk Watch App/WatchContainerData.swift

import Foundation
import SwiftUI
import Combine // Importera Combine

// Hanterar listan med kärl (Container) för WatchApp
class WatchContainerData: ObservableObject {
    static let shared = WatchContainerData() // Singleton

    @Published var containerList: [Container] = []
    @Published var isLoading: Bool = true
    private var cancellables = Set<AnyCancellable>()

    // URL till lokal cache-fil för WatchApp
    private var localCacheURL: URL? {
        // Använd Application Support även på klockan
        guard let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("WatchContainerData Error: Could not find Application Support directory.")
            return nil
        }
        let subDirectory = appSupportDirectory.appendingPathComponent("DataCache")
        do {
            try FileManager.default.createDirectory(at: subDirectory, withIntermediateDirectories: true, attributes: nil)
            // Eget namn för klockans cache
            return subDirectory.appendingPathComponent("containerListCache_watch.json")
        } catch {
            print("WatchContainerData Error: Could not create cache subdirectory: \(error)")
            return nil
        }
    }

    private init() {
        print("WatchContainerData [Watch]: init called.")

        // 1. Ladda från lokal cache
        if loadContainersLocally() {
            print("WatchContainerData [Watch]: Successfully loaded from local cache.")
            self.isLoading = false
        } else {
            print("WatchContainerData [Watch]: Local cache empty or failed to load.")
        }

        // 2. Lyssna på CloudKit-uppdateringar
        CloudKitContainerDataStore.shared.containerListNeedsUpdate
            .sink { [weak self] in
                print("WatchContainerData [Watch]: Received CloudKit update signal. Fetching...")
                self?.loadContainersFromCloudKit()
            }
            .store(in: &cancellables)

        // 3. Starta initial CloudKit-hämtning i bakgrunden
        print("WatchContainerData [Watch]: Initiating background CloudKit fetch from init.")
        loadContainersFromCloudKit()
    }

    // --- Lokala Cache-funktioner ---

    private func loadContainersLocally() -> Bool {
        guard let url = localCacheURL else { return false }
        print("WatchContainerData [Watch]: Attempting to load cache from: \(url.path)")
        guard FileManager.default.fileExists(atPath: url.path) else { return false }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let cachedList = try decoder.decode([Container].self, from: data)
            self.containerList = cachedList.sorted { $0.name.lowercased() < $1.name.lowercased() } // Sortera
            print("WatchContainerData [Watch]: Successfully loaded \(self.containerList.count) containers from cache.")
            return true
        } catch {
            print("WatchContainerData [Watch]: Error loading/decoding local container cache: \(error)")
            try? FileManager.default.removeItem(at: url)
            return false
        }
    }

    private func saveContainersLocally() {
        guard let url = localCacheURL else { return }
        let listToSave = self.containerList
        print("WatchContainerData [Watch]: Attempting to save \(listToSave.count) containers to cache: \(url.path)")

        DispatchQueue.global(qos: .background).async { // Spara i bakgrunden
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(listToSave)
                try data.write(to: url, options: [.atomic])
                print("WatchContainerData [Watch]: Successfully saved container cache.")
            } catch {
                print("WatchContainerData [Watch]: Error encoding/saving local container cache: \(error)")
            }
        }
    }

    // --- CloudKit Fetch ---

    func loadContainersFromCloudKit() {
         DispatchQueue.main.async { if self.containerList.isEmpty { self.isLoading = true } }
        print("WatchContainerData [Watch]: loadContainersFromCloudKit called.")

        CloudKitContainerDataStore.shared.fetchContainers { [weak self] (items, error) in
            guard let self = self else { return }
            print("WatchContainerData [Watch]: CloudKit fetch completion handler started.")

            DispatchQueue.main.async { // Uppdatera UI på huvudtråden
                 self.isLoading = false
                 if let error = error {
                     print("WatchContainerData [Watch]: Error fetching containers from CloudKit: \(error)")
                     return
                 }
                 let receivedItems = items ?? []
                 print("WatchContainerData [Watch]: CloudKit fetch successful. Received \(receivedItems.count) containers.")
                 let sortedReceivedItems = receivedItems.sorted { $0.name.lowercased() < $1.name.lowercased() }

                 if self.containerList != sortedReceivedItems {
                     print("WatchContainerData [Watch]: CloudKit data differs. Updating UI and saving cache.")
                     self.containerList = sortedReceivedItems
                     self.saveContainersLocally() // Spara ny data till cache
                 } else {
                    print("WatchContainerData [Watch]: CloudKit container data same as local.")
                 }
             }
        }
    }

    // Inga funktioner för att lägga till/ändra/ta bort kärl från klockan i detta exempel.
    // Om det behövs, lägg till dem här på samma sätt som i ContainerData (iOS).
}
