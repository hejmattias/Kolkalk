// Kolkalk/ContentView.swift

import SwiftUI
import UniformTypeIdentifiers
import WatchConnectivity

struct ContentView: View {
    @ObservedObject var viewModel = ViewModel.shared
    @State private var showingDocumentPicker = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Importera CSV-fil och skicka till Apple Watch")
                    .font(.headline)
                    .padding()

                Button(action: {
                    showingDocumentPicker = true
                }) {
                    Text("Välj CSV-fil")
                        .font(.title2)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .sheet(isPresented: $showingDocumentPicker) {
                    DocumentPicker { url in
                        viewModel.sendCSVFile(fileURL: url)
                    }
                }

                if !viewModel.transferStatus.isEmpty {
                    Text(viewModel.transferStatus)
                        .padding()
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Sektion för att exportera livsmedelslistan
                Text("Exportera livsmedelslista från Apple Watch")
                    .font(.headline)
                    .padding()

                Button(action: {
                    // Be Apple Watch att skicka livsmedelslistan
                    viewModel.requestFoodListFromWatch()
                }) {
                    Text("Begär livsmedelslista")
                        .font(.title2)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                if !viewModel.receivedFoodList.isEmpty {
                    Button(action: {
                        viewModel.exportFoodListToCSV()
                    }) {
                        Text("Exportera mottagen livsmedelslista")
                            .font(.title2)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }

                // Knappar för "Hantera Kärl"
                NavigationLink(destination: ContainerListView()) {
                    Text("Hantera Kärl")
                        .font(.title2)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                Spacer()
            }
            .navigationTitle("Kolkalk iOS App")
        }
    }
}

// Uppdaterad DocumentPicker-struktur med hantering av säkerhetsskyddade resurser
struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types = [UTType.commaSeparatedText, UTType.plainText]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // Ingen uppdatering behövs
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            // Börja åtkomst till säkerhetsskyddad resurs
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                // Kopiera filen till en lokal plats om det behövs
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                do {
                    if FileManager.default.fileExists(atPath: tempURL.path) {
                        try FileManager.default.removeItem(at: tempURL)
                    }
                    try FileManager.default.copyItem(at: url, to: tempURL)
                    DispatchQueue.main.async {
                        self.onPick(tempURL)
                    }
                } catch {
                    print("Fel vid kopiering av fil: \(error)")
                }
            } else {
                // Hantera fel vid åtkomst
                print("Kunde inte få åtkomst till säkerhetsskyddad resurs.")
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // Hantera om användaren avbryter, om nödvändigt
        }
    }
}

