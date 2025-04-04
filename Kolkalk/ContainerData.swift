// Kolkalk/ContainerData.swift

import Foundation
import SwiftUI
import Combine
import CloudKit // <-- Lade till import

// Hanterar listan med kärl (Container) för iOS-appen
class ContainerData: ObservableObject {
    static let shared = ContainerData() // Singleton för enkel åtkomst

    @Published var containerList: [Container] = []
    @Published var isLoading: Bool = true // För laddningsindikator
    // *** NYTT: För att spåra synkstatus ***
    @Published var lastSyncTime: Date? = nil
    @Published var lastSyncError: Error? = nil
    // *** SLUT NYTT ***
    private var cancellables = Set<AnyCancellable>()

    // URL till lokal cache-fil för iOS
    private var localCacheURL: URL? {
        guard let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("ContainerData Error: Could not find Application Support directory.")
            return nil
        }
        let subDirectory = appSupportDirectory.appendingPathComponent("DataCache")
        do {
            try FileManager.default.createDirectory(at: subDirectory, withIntermediateDirectories: true, attributes: nil)
            return subDirectory.appendingPathComponent("containerListCache_iOS.json")
        } catch {
            print("ContainerData Error: Could not create cache subdirectory: \(error)")
            return nil
        }
    }

    // Privat init för Singleton
    private init() {
        print("ContainerData [iOS]: init called.")
        // 1. Ladda från lokal cache
        if loadContainersLocally() {
            print("ContainerData [iOS]: Successfully loaded from local cache.")
            self.isLoading = false
        } else {
            print("ContainerData [iOS]: Local cache empty or failed to load.")
        }
        // 2. Lyssna på CloudKit-uppdateringar
        CloudKitContainerDataStore.shared.containerListNeedsUpdate
            .sink { [weak self] in
                print("ContainerData [iOS]: Received CloudKit update signal. Fetching...")
                self?.loadContainersFromCloudKit()
            }
            .store(in: &cancellables)
        // 3. Starta initial CloudKit-hämtning i bakgrunden
        print("ContainerData [iOS]: Initiating background CloudKit fetch from init.")
        loadContainersFromCloudKit()
    }

    // --- Lokala Cache-funktioner --- (Oförändrade)
    private func loadContainersLocally() -> Bool {
        guard let url = localCacheURL else { return false }
        print("ContainerData [iOS]: Attempting to load cache from: \(url.path)")
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let cachedList = try decoder.decode([Container].self, from: data)
            self.containerList = cachedList.sorted { $0.name.lowercased() < $1.name.lowercased() }
            print("ContainerData [iOS]: Successfully loaded \(self.containerList.count) containers from cache.")
            return true
        } catch {
            print("ContainerData [iOS]: Error loading/decoding local container cache: \(error)")
            try? FileManager.default.removeItem(at: url)
            return false
        }
    }
    private func saveContainersLocally() {
        guard let url = localCacheURL else { return }
        let listToSave = self.containerList
        print("ContainerData [iOS]: Attempting to save \(listToSave.count) containers to cache: \(url.path)")
        DispatchQueue.global(qos: .background).async {
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(listToSave)
                try data.write(to: url, options: [.atomic])
                print("ContainerData [iOS]: Successfully saved container cache.")
            } catch {
                print("ContainerData [iOS]: Error encoding/saving local container cache: \(error)")
            }
        }
    }

    // --- CloudKit Fetch --- (UPPDATERAD med synkstatus)
    func loadContainersFromCloudKit() {
        DispatchQueue.main.async {
            if !self.isLoading { self.isLoading = true } // Starta bara om vi inte redan laddar
            self.lastSyncError = nil // Nollställ fel inför ny hämtning
        }
        print("ContainerData [iOS]: loadContainersFromCloudKit called.")
        CloudKitContainerDataStore.shared.fetchContainers { [weak self] (items, error) in
            guard let self = self else { return }
            print("ContainerData [iOS]: CloudKit fetch completion handler started.")
            DispatchQueue.main.async {
                 self.isLoading = false // Sluta ladda (alltid)
                 if let error = error {
                     print("ContainerData [iOS]: Error fetching containers from CloudKit: \(error)")
                     self.lastSyncError = error // *** SPARA FELET ***
                     return
                 }
                 // *** SÄTT TID OCH NOLLSTÄLL FEL VID LYCKAD HÄMTNING ***
                 self.lastSyncTime = Date()
                 self.lastSyncError = nil

                 let receivedItems = items ?? []
                 print("ContainerData [iOS]: CloudKit fetch successful. Received \(receivedItems.count) containers.")
                 let sortedReceivedItems = receivedItems.sorted { $0.name.lowercased() < $1.name.lowercased() }
                 if self.containerList != sortedReceivedItems {
                     print("ContainerData [iOS]: CloudKit data differs. Updating UI and saving cache.")
                     self.containerList = sortedReceivedItems
                     self.saveContainersLocally()
                 } else {
                    print("ContainerData [iOS]: CloudKit container data same as local.")
                 }
             }
        }
    }

    // --- Modifieringsfunktioner (iOS) --- (UPPDATERADE med synkstatus)
    func addContainer(_ container: Container) {
        // Optimistisk UI-uppdatering (oförändrad)
        DispatchQueue.main.async {
            if !self.containerList.contains(where: { $0.id == container.id }) {
                self.containerList.append(container)
                self.sortContainerList()
                self.saveContainersLocally()
                print("ContainerData [iOS]: Added container locally & saved cache. ID: \(container.id)")
            } else { return }
        }
        // CloudKit save
        CloudKitContainerDataStore.shared.saveContainer(container) { [weak self] error in
            // *** ÄNDRING: Uppdatera lastSyncTime/Error vid lyckad/misslyckad save ***
            DispatchQueue.main.async {
                guard let self = self else { return }
                 if let error = error {
                     print("ContainerData Error: CK save failed (add) ID \(container.id): \(error)")
                     self.lastSyncError = error // Spara felet
                 } else {
                     print("ContainerData [iOS]: CK save success (add) ID \(container.id)")
                     self.lastSyncTime = Date() // Sätt tiden
                     self.lastSyncError = nil // Nollställ felet
                 }
             }
            // *** SLUT ÄNDRING ***
        }
    }
    func updateContainer(_ container: Container) {
        // Optimistisk UI-uppdatering (oförändrad)
        DispatchQueue.main.async {
            if let index = self.containerList.firstIndex(where: { $0.id == container.id }) {
                self.containerList[index] = container
                self.sortContainerList()
                self.saveContainersLocally()
                print("ContainerData [iOS]: Updated container locally & saved cache. ID: \(container.id)")
            } else { return }
        }
        // CloudKit save
        CloudKitContainerDataStore.shared.saveContainer(container) { [weak self] error in
             // *** ÄNDRING: Uppdatera lastSyncTime/Error vid lyckad/misslyckad save ***
             DispatchQueue.main.async {
                guard let self = self else { return }
                 if let error = error {
                     print("ContainerData Error: CK save failed (update) ID \(container.id): \(error)")
                     self.lastSyncError = error // Spara felet
                 } else {
                     print("ContainerData [iOS]: CK save success (update) ID \(container.id)")
                     self.lastSyncTime = Date() // Sätt tiden
                     self.lastSyncError = nil // Nollställ felet
                 }
             }
            // *** SLUT ÄNDRING ***
        }
    }
    func deleteContainer(_ container: Container) {
        // Optimistisk UI-uppdatering (oförändrad)
        DispatchQueue.main.async {
            let originalCount = self.containerList.count
            self.containerList.removeAll { $0.id == container.id }
            if self.containerList.count < originalCount {
                self.saveContainersLocally()
                print("ContainerData [iOS]: Deleted container locally & saved cache. ID: \(container.id)")
            } else { return }
        }
        // CloudKit delete
        CloudKitContainerDataStore.shared.deleteContainer(withId: container.id) { [weak self] error in
             // *** ÄNDRING: Uppdatera lastSyncTime/Error vid lyckad/misslyckad delete ***
             DispatchQueue.main.async {
                guard let self = self else { return }
                 if let error = error {
                     print("ContainerData Error: CK delete failed ID \(container.id): \(error)")
                     self.lastSyncError = error // Spara felet
                     // Återställ genom att ladda om vid fel?
                     self.loadContainersFromCloudKit()
                 } else {
                     print("ContainerData [iOS]: CK delete success ID \(container.id)")
                     self.lastSyncTime = Date() // Sätt tiden
                     self.lastSyncError = nil // Nollställ felet
                 }
             }
            // *** SLUT ÄNDRING ***
        }
    }

    // Radera alla kärl (UPPDATERAD med synkstatus)
    func deleteAllContainers() {
        let containersToDelete = self.containerList
        guard !containersToDelete.isEmpty else { return }
        let recordIDsToDelete = containersToDelete.map { CKRecord.ID(recordName: $0.id.uuidString) }

        // Optimistisk UI-uppdatering (oförändrad)
        DispatchQueue.main.async {
            self.containerList.removeAll()
            self.saveContainersLocally()
            print("ContainerData [iOS]: Deleted all containers locally & saved cache.")
        }

        // CloudKit delete all
        let operation = CKModifyRecordsOperation(recordsToSave: nil as [CKRecord]?, recordIDsToDelete: recordIDsToDelete)
        operation.savePolicy = .allKeys // Irrelevant för delete
        operation.modifyRecordsResultBlock = { [weak self] (result: Result<Void, Error>) in
            // *** ÄNDRING: Uppdatera lastSyncTime/Error vid lyckad/misslyckad delete all ***
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success():
                    print("ContainerData [iOS]: Successfully deleted all containers from CloudKit.")
                    self.lastSyncTime = Date() // Sätt tiden
                    self.lastSyncError = nil // Nollställ felet
                case .failure(let error):
                    print("ContainerData Error: Failed to delete all containers from CloudKit: \(error)")
                    self.lastSyncError = error // Spara felet
                    self.loadContainersFromCloudKit() // Ladda om vid fel
                }
            }
            // *** SLUT ÄNDRING ***
        }
        CloudKitContainerDataStore.shared.database.add(operation)
    }

    // Privat sorteringsfunktion (Oförändrad)
    private func sortContainerList() {
        // Körs på main thread eftersom den muterar @Published property
        DispatchQueue.main.async {
            self.containerList.sort { $0.name.lowercased() < $1.name.lowercased() }
        }
    }
}
