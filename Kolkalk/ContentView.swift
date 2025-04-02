// Kolkalk/ContentView.swift

import SwiftUI
import UniformTypeIdentifiers // För UTType
import CloudKit
import UIKit // <-- ***** LADE TILL DENNA IMPORT *****

// Omslagsstruktur för URL som är Identifiable
struct ShareableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// Hjälpstruktur för att visa fel i .alert
struct IdentifiableError: Identifiable {
    let id = UUID()
    let error: Error
}

struct ContentView: View {
    @StateObject var viewModel = ViewModel.shared
    @StateObject var foodData = FoodData_iOS()

    @State private var showingDocumentPicker = false
    @State private var shareableURL: ShareableURL? = nil
    @State private var importStatus: String? = nil
    @State private var fileOperationError: IdentifiableError? = nil

    private let foodListNavigationID = "showFoodList"
    private let containerListNavigationID = "showContainerList" // Om du implementerar den

    var body: some View {
        // Använder NavigationStack
        NavigationStack {
            List {
                // --- Livsmedelshantering (iCloud) ---
                Section("Livsmedel (iCloud)") {
                    NavigationLink(value: foodListNavigationID) {
                        Label("Hantera livsmedel", systemImage: "list.bullet")
                    }
                    Button { showingDocumentPicker = true } label: {
                        Label("Importera CSV till iCloud", systemImage: "square.and.arrow.down")
                    }
                    Button { exportFoodList() } label: {
                         Label("Exportera livsmedel som CSV", systemImage: "square.and.arrow.up")
                     }
                    if let status = importStatus {
                         Text(status).font(.caption).foregroundColor(.gray)
                             .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 5) { importStatus = nil } }
                    }
                }

                 // --- Kärlhantering (CloudKit) ---
                 Section("Kärl (CloudKit)") {
                     NavigationLink(destination: ContainerListView()) { // Fungerar troligen OK här
                         Label("Hantera Kärl", systemImage: "cylinder.split.1x2")
                     }
                 }
                 // --- Inställningar ---
            }
            .navigationTitle("Kolkalk iOS")
            .navigationDestination(for: String.self) { value in // Hanterar value-länkar
                if value == foodListNavigationID {
                    IOSFoodListView(foodData: foodData)
                }
                // Lägg till fler else if här...
            }
            .sheet(isPresented: $showingDocumentPicker) {
                 DocumentPicker { url in // Presenterar DocumentPicker
                     importStatus = "Startar import..."
                      foodData.importFromCSV(fileURL: url) { result in
                          DispatchQueue.main.async {
                              switch result {
                              case .success(let count):
                                  importStatus = "Importerade \(count) livsmedel."
                              case .failure(let error):
                                   self.fileOperationError = IdentifiableError(error: error)
                                   importStatus = "Importfel. Se detaljer."
                              }
                          }
                      }
                 }
            }
            .sheet(item: $shareableURL) { wrapper in // Presenterar ShareSheet
                 ShareSheet(activityItems: [wrapper.url])
             }
            .alert(item: $fileOperationError) { errorWrapper in // Visar felmeddelande
                 Alert(title: Text("Filfel"),
                       message: Text(errorWrapper.error.localizedDescription),
                       dismissButton: .default(Text("OK")))
            }
            .onAppear {
                 HealthKitManager.shared.requestAuthorization { success, error in /* ... */ }
             }
        } // Slut NavigationStack
    }

    // exportFoodList (oförändrad)
     func exportFoodList() {
         importStatus = "Skapar CSV-fil..."
         foodData.exportToCSV { result in
              DispatchQueue.main.async {
                  switch result {
                  case .success(let url):
                      self.shareableURL = ShareableURL(url: url)
                      importStatus = "CSV-fil redo att delas."
                  case .failure(let error):
                      self.fileOperationError = IdentifiableError(error: error)
                      importStatus = "Exportfel."
                  }
             }
          }
      }
}


// DocumentPicker implementerar UIViewControllerRepresentable
struct DocumentPicker: UIViewControllerRepresentable {
     var onPick: (URL) -> Void

     // Skapar UIKit-vyn
     func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
         let allowedTypes: [UTType] = [.commaSeparatedText, .plainText, UTType(mimeType: "public.comma-separated-values-text")].compactMap { $0 }
         // Felsäkring om UTType misslyckas (bör inte hända här)
         guard !allowedTypes.isEmpty else {
            print("DocumentPicker Warning: No valid UTTypes available, falling back to plainText.")
            return UIDocumentPickerViewController(forOpeningContentTypes: [.plainText])
         }
         let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes, asCopy: true)
         picker.delegate = context.coordinator // Sätt Coordinator som delegate
         picker.allowsMultipleSelection = false
         return picker
     }

     // Uppdaterar UIKit-vyn (behövs sällan för denna typ)
     func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

     // Skapar Coordinator för att hantera delegate-anrop
     func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

     // Coordinator-klass som hanterar UIDocumentPickerDelegate
     class Coordinator: NSObject, UIDocumentPickerDelegate {
         var onPick: (URL) -> Void
         init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

         // Anropas när användaren valt en fil
         func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
             guard let url = urls.first else { return } // Ta första valda URL:en
             onPick(url) // Skicka URL:en tillbaka via closure
         }

         // Anropas om användaren avbryter (valfritt att hantera)
         func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            print("DocumentPicker was cancelled.")
         }
     }
}

// ShareSheet implementerar UIViewControllerRepresentable
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any] // Det som ska delas (t.ex. en URL)
    var applicationActivities: [UIActivity]? = nil // Ev. egna aktiviteter

    // Skapar UIKit-vyn (UIActivityViewController)
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    // Uppdaterar UIKit-vyn (behövs normalt inte för denna)
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
