// Shared/Container.swift

import Foundation
import UIKit // Behövs för UIImage om du hanterar det direkt, men bättre med Data
import CloudKit // <-- Lade till import

// Gör structen Equatable för att kunna jämföra listor
struct Container: Identifiable, Codable, Hashable, Equatable {
    let id: UUID
    var name: String
    var weight: Double
    var imageData: Data? // Behåll som Data

    // Definiera recordType här eller skicka in den till toCKRecord
    static let cloudKitRecordType = "ContainerRecord" // Definiera recordTypen här

    // Standard initialiserare
    init(id: UUID = UUID(), name: String, weight: Double, imageData: Data? = nil) {
        self.id = id
        self.name = name
        self.weight = weight
        self.imageData = imageData
    }

    // MARK: - CloudKit Conversion

    /// Skapar ett Container-objekt från ett CKRecord.
    init?(record: CKRecord) {
        // Kontrollera att recordTypen stämmer (valfritt men bra)
        guard record.recordType == Container.cloudKitRecordType else {
             print("Container Error: Incorrect record type provided. Expected '\(Container.cloudKitRecordType)', got '\(record.recordType)'")
             return nil
         }

        let uuidString = record.recordID.recordName
        guard let id = UUID(uuidString: uuidString),
              let name = record["name"] as? String,
              let weight = record["weight"] as? Double else {
            print("Container Error: Failed to initialize from record \(record.recordID.recordName). Missing required fields.")
            return nil
        }

        self.id = id
        self.name = name
        self.weight = weight

        // Hämta bilddata från CKAsset
        if let imageAsset = record["image"] as? CKAsset,
           let imageURL = imageAsset.fileURL {
            do {
                self.imageData = try Data(contentsOf: imageURL)
            } catch {
                print("Container Error: Failed to load image data from asset URL for \(name): \(error)")
                self.imageData = nil
            }
        } else {
            self.imageData = nil
        }
    }

    /// Konverterar Container-objektet till ett CKRecord för sparande i CloudKit.
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: self.id.uuidString)
        // Använd den statiska recordTypen från structen
        let record = CKRecord(recordType: Container.cloudKitRecordType, recordID: recordID)

        record["name"] = self.name as CKRecordValue
        record["weight"] = self.weight as CKRecordValue

        // Hantera bilddata -> CKAsset
        if let data = self.imageData {
            let tempDir = FileManager.default.temporaryDirectory
            let tempURL = tempDir.appendingPathComponent("\(UUID().uuidString).jpg")
            do {
                try data.write(to: tempURL)
                let imageAsset = CKAsset(fileURL: tempURL)
                record["image"] = imageAsset
                 // print("Container Info: Created CKAsset for \(self.name)")
            } catch {
                print("Container Error: Failed to write image data to temporary file for \(self.name): \(error)")
                // *** FIX: Tilldela nil explicit typat ***
                record["image"] = nil as CKRecordValue?
            }
        } else {
            // *** FIX: Tilldela nil explicit typat ***
            record["image"] = nil as CKRecordValue?
        }

        return record
    }

    // Equatable (oförändrad)
    static func == (lhs: Container, rhs: Container) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.weight == rhs.weight &&
               lhs.imageData == rhs.imageData
    }
}
