// Kolkalk/ContentView.swift

import SwiftUI
import UniformTypeIdentifiers
import CloudKit // Behåll importen

// Omslagsstruktur för URL som är Identifiable
struct ShareableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct ContentView: View {
    // Skapa instanser här
    @StateObject var viewModel = ViewModel.shared
    @StateObject var foodData = FoodData_iOS()

    @State private var showingDocumentPicker = false
    @State private var shareableURL: ShareableURL? = nil
    @State private var importStatus: String? = nil

    var body: some View {
        NavigationView {
            List {
                // --- Livsmedelshantering (iCloud) ---
                Section("Livsmedel (iCloud)") {
                    NavigationLink(destination: IOSFoodListView(foodData: foodData)) {
                        Label("Hantera livsmedel", systemImage: "list.bullet")
                    }

                    Button {
                        showingDocumentPicker = true
                    } label: {
                        Label("Importera CSV till iCloud", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        exportFoodList()
                    } label: {
                         Label("Exportera livsmedel som CSV", systemImage: "square.and.arrow.up")
                     }

                    if let status = importStatus {
                         Text(status)
                             .font(.caption)
                             .foregroundColor(.gray)
                             .onAppear {
                                 DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                     importStatus = nil
                                 }
                             }
                    }
                }

                 // --- Kärlhantering (WCSession eller CloudKit?) ---
                 Section("Kärl (via Klocka)") {
                     NavigationLink(destination: ContainerListView()) {
                         Label("Hantera Kärl", systemImage: "cylinder.split.1x2")
                     }
                     Button {
                         viewModel.sendContainersToWatch(containerData: ContainerData.shared)
                     } label: {
                         Label("Synkronisera Kärl till Klocka", systemImage: "arrow.clockwise.icloud") // Korrekt ikon
                     }
                      if !viewModel.transferStatus.isEmpty {
                          Text(viewModel.transferStatus)
                              .font(.caption)
                              .foregroundColor(.gray)
                               .onAppear {
                                   DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                       viewModel.transferStatus = ""
                                   }
                               }
                      }
                 }

                 // --- Inställningar ---
                 // Lägg till länk här vid behov
            }
            .navigationTitle("Kolkalk iOS")
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPicker { url in
                    importStatus = "Importerar CSV..."
                     foodData.importFromCSV(fileURL: url) { result in
                         DispatchQueue.main.async {
                             switch result {
                             case .success(let count):
                                 importStatus = "Importerade \(count) livsmedel."
                             case .failure(let error):
                                 if let ckError = error as? CKError {
                                      // Ge mer detaljerad feedback vid CloudKit-fel
                                      let errorDesc = ckError.userInfo[NSLocalizedDescriptionKey] as? String ?? "Okänt CloudKit-fel"
                                      importStatus = "Importfel (CK\(ckError.code.rawValue)): \(errorDesc)"
                                  } else {
                                      importStatus = "Importfel: \(error.localizedDescription)"
                                  }
                             }
                         }
                     }
                }
            }
            // Använd .sheet(item: $shareableURL)
            .sheet(item: $shareableURL) { wrapper in
                 ShareSheet(activityItems: [wrapper.url])
             }
            .onAppear {
                 HealthKitManager.shared.requestAuthorization { success, error in
                     // ... befintlig kod ...
                 }
                 // Försök ladda listan när vyn visas (om CloudKit är konfigurerat)
                 // foodData.loadFoodList() // Kan avkommenteras när CK funkar
             }
        }
    }

    // Funktion för att exportera CSV
    func exportFoodList() {
        importStatus = "Exporterar..." // Visa status
        foodData.exportToCSV { result in
             DispatchQueue.main.async {
                 switch result {
                 case .success(let url):
                     self.shareableURL = ShareableURL(url: url) // Sätt objektet, sheet öppnas
                     importStatus = "CSV-fil skapad."
                 case .failure(let error):
                     print("Export failed: \(error)")
                     importStatus = "Exportfel: \(error.localizedDescription)"
                 }
            }
         }
     }
}

// DocumentPicker med säkrare UTType-hantering
struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // *** ÄNDRING: Skapa arrayen säkert med compactMap ***
        let allowedTypes: [UTType] = [
            .commaSeparatedText, // Standard CSV
            .plainText,         // Vanlig textfil (kan ibland användas för CSV)
            UTType(mimeType: "public.comma-separated-values-text") // Försök med specifik MIME-typ
        ].compactMap { $0 } // compactMap tar bort eventuella nil-värden

        print("DocumentPicker allowed types: \(allowedTypes.map { $0.identifier })") // Logga för felsökning

        // Se till att arrayen inte är tom innan du skapar controllern
        guard !allowedTypes.isEmpty else {
            // Detta bör inte hända med typerna ovan, men bra att ha en fallback
            print("Error: No valid UTTypes available for DocumentPicker.")
            // Returnera en tom controller eller hantera felet på annat sätt
            return UIDocumentPickerViewController(forOpeningContentTypes: [.plainText]) // Fallback
        }

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }; onPick(url)
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
    }
}


// ShareSheet (ingen ändring behövs här)
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
