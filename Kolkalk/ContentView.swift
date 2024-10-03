import SwiftUI
import UniformTypeIdentifiers

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

                // Ny sektion för att exportera livsmedelslistan
                Text("Exportera livsmedelslista från Apple Watch")
                    .font(.headline)
                    .padding()

                Button(action: {
                    if viewModel.receivedFoodList.isEmpty {
                        viewModel.transferStatus = "Ingen livsmedelslista mottagen."
                    } else {
                        viewModel.exportFoodListToCSV()
                    }
                }) {
                    Text("Exportera livsmedelslista")
                        .font(.title2)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                Spacer()
            }
            .navigationTitle("Kolkalk iOS App")
        }
    }
}

// Inkludera DocumentPicker-strukturen här
struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types = [UTType.commaSeparatedText]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
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
            if let url = urls.first {
                onPick(url)
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // Hantera om användaren avbryter
        }
    }
}
