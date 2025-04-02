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

    // --- CloudKit Fetch --- (Oförändrad)
    func loadContainersFromCloudKit() {
         DispatchQueue.main.async { if self.containerList.isEmpty { self.isLoading = true } }
        print("ContainerData [iOS]: loadContainersFromCloudKit called.")
        CloudKitContainerDataStore.shared.fetchContainers { [weak self] (items, error) in
            guard let self = self else { return }
            print("ContainerData [iOS]: CloudKit fetch completion handler started.")
            DispatchQueue.main.async {
                 self.isLoading = false
                 if let error = error {
                     print("ContainerData [iOS]: Error fetching containers from CloudKit: \(error)")
                     return
                 }
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

    // --- Modifieringsfunktioner (iOS) --- (Oförändrade)
    func addContainer(_ container: Container) {
        DispatchQueue.main.async {
            if !self.containerList.contains(where: { $0.id == container.id }) {
                self.containerList.append(container)
                self.sortContainerList()
                self.saveContainersLocally()
                print("ContainerData [iOS]: Added container locally & saved cache. ID: \(container.id)")
            } else { return }
        }
        CloudKitContainerDataStore.shared.saveContainer(container) { error in
             if let error = error { print("ContainerData Error: CK save failed (add) ID \(container.id): \(error)") }
             else { print("ContainerData [iOS]: CK save success (add) ID \(container.id)") }
        }
    }
    func updateContainer(_ container: Container) {
        DispatchQueue.main.async {
            if let index = self.containerList.firstIndex(where: { $0.id == container.id }) {
                self.containerList[index] = container
                self.sortContainerList()
                self.saveContainersLocally()
                print("ContainerData [iOS]: Updated container locally & saved cache. ID: \(container.id)")
            } else { return }
        }
        CloudKitContainerDataStore.shared.saveContainer(container) { error in
            if let error = error { print("ContainerData Error: CK save failed (update) ID \(container.id): \(error)") }
             else { print("ContainerData [iOS]: CK save success (update) ID \(container.id)") }
        }
    }
    func deleteContainer(_ container: Container) {
        DispatchQueue.main.async {
            let originalCount = self.containerList.count
            self.containerList.removeAll { $0.id == container.id }
            if self.containerList.count < originalCount {
                self.saveContainersLocally()
                print("ContainerData [iOS]: Deleted container locally & saved cache. ID: \(container.id)")
            } else { return }
        }
        CloudKitContainerDataStore.shared.deleteContainer(withId: container.id) { error in
             if let error = error { print("ContainerData Error: CK delete failed ID \(container.id): \(error)") }
             else { print("ContainerData [iOS]: CK delete success ID \(container.id)") }
        }
    }

    // Radera alla kärl (om det behövs en sådan funktion)
    func deleteAllContainers() {
        let containersToDelete = self.containerList
        guard !containersToDelete.isEmpty else { return }
        // *** FIX: Behöver CKRecord ***
        let recordIDsToDelete = containersToDelete.map { CKRecord.ID(recordName: $0.id.uuidString) }

        DispatchQueue.main.async {
            self.containerList.removeAll()
            self.saveContainersLocally()
            print("ContainerData [iOS]: Deleted all containers locally & saved cache.")
        }

        // *** FIX: Behöver CKModifyRecordsOperation och korrekt nil-typning ***
        let operation = CKModifyRecordsOperation(recordsToSave: nil as [CKRecord]?, recordIDsToDelete: recordIDsToDelete)
        // *** FIX: Behöver full typ för savePolicy ***
        operation.savePolicy = CKModifyRecordsOperation.RecordSavePolicy.allKeys
        // *** FIX: Result kan behöva explicit typ om import inte räcker ***
        operation.modifyRecordsResultBlock = { [weak self] (result: Result<Void, Error>) in // Explicit typ
            switch result {
            case .success():
                print("ContainerData [iOS]: Successfully deleted all containers from CloudKit.")
            case .failure(let error):
                print("ContainerData Error: Failed to delete all containers from CloudKit: \(error)")
                DispatchQueue.main.async { self?.loadContainersFromCloudKit() } // Ladda om vid fel
            }
        }
        CloudKitContainerDataStore.shared.database.add(operation)
    }

    // Privat sorteringsfunktion (Oförändrad)
    private func sortContainerList() {
        self.containerList.sort { $0.name.lowercased() < $1.name.lowercased() }
    }
}
