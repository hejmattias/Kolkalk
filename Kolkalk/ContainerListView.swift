// Kolkalk/ContainerListView.swift

import SwiftUI

struct ContainerListView: View {
    @ObservedObject var containerData = ContainerData.shared
    @State private var showingAddContainer = false
    @State private var editingContainer: Container?

    // *** NYTT: Formatter för tid ***
    private static var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()
    // *** SLUT NYTT ***

    var body: some View {
        // *** ÄNDRING: Omslut med ZStack för att kunna visa laddningsindikator över listan ***
        ZStack {
            List {
                ForEach(containerData.containerList) { container in
                    HStack {
                        if let imageData = container.imageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50)
                                .cornerRadius(5) // Lite rundade hörn
                                .shadow(radius: 1) // Liten skugga
                        } else {
                            // Placeholder-bild
                            Image(systemName: "cylinder.split.1x2") // Mer passande ikon
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40) // Justerad storlek
                                .foregroundColor(.gray)
                                .padding(5) // Lite luft runt ikonen
                                .background(Color(uiColor: .systemGray6)) // Bakgrund
                                .cornerRadius(5)
                        }

                        VStack(alignment: .leading) {
                            Text(container.name).font(.headline) // Tydligare headline
                            Text("\(container.weight, specifier: "%.0f") g")
                                .font(.subheadline) // Subheadline för vikten
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4) // Lite mer luft vertikalt
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingContainer = container
                    }
                    // *** NYTT: Swipe Actions ***
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteContainerAction(container: container)
                        } label: {
                            Label("Ta bort", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            editingContainer = container
                        } label: {
                            Label("Redigera", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    // *** SLUT NYTT ***
                }
                .onDelete(perform: deleteContainer) // Behåll för Edit-mode delete

                // *** NYTT: Status Section ***
                Section {
                    HStack {
                        if containerData.isLoading {
                            ProgressView().padding(.trailing, 5)
                            Text("Synkroniserar...").foregroundColor(.secondary)
                        } else if let error = containerData.lastSyncError {
                            Image(systemName: "exclamationmark.icloud.fill").foregroundColor(.red)
                            // Visa bara "Synkfel" och logga detaljer vid tap
                            Text("Synkfel")
                                .foregroundColor(.secondary)
                                .onTapGesture {
                                     print("Container Sync Error Details: \(error.localizedDescription)")
                                     // Överväg att visa en alert här istället
                                 }
                        } else if let syncTime = containerData.lastSyncTime {
                            Image(systemName: "checkmark.icloud.fill").foregroundColor(.green)
                            Text("Synkad: \(syncTime, formatter: Self.timeFormatter)").foregroundColor(.secondary)
                        } else {
                            Image(systemName: "icloud.slash").foregroundColor(.gray)
                            Text("Väntar på synk...").foregroundColor(.secondary)
                        }
                        Spacer()
                        Button {
                            containerData.loadContainersFromCloudKit()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(containerData.isLoading) // Inaktivera vid laddning
                    }
                    .font(.caption) // Mindre text för status
                }
                // *** SLUT NYTT ***

            } // Slut List

            // *** NYTT: Laddningsindikator över listan ***
            if containerData.isLoading && containerData.containerList.isEmpty {
                 VStack { // Centrera indikatorn
                     Spacer()
                     ProgressView("Laddar kärl...")
                     Spacer()
                 }
                 .frame(maxWidth: .infinity, maxHeight: .infinity)
                 .background(Color.black.opacity(0.1)) // Lätt genomskinlig bakgrund
            }
            // *** SLUT NYTT ***

        } // Slut ZStack
        .navigationTitle("Kärl")
        .navigationBarItems(
            leading: EditButton(),
            trailing: Button(action: {
                editingContainer = nil // Nollställ vid klick på '+'
                showingAddContainer = true
            }) {
                Image(systemName: "plus")
            }
        )
        .sheet(isPresented: $showingAddContainer) {
            // Skicka med en callback för att nollställa editingContainer
            AddEditContainerView(containerData: containerData)
        }
        .sheet(item: $editingContainer) { container in
            AddEditContainerView(containerData: containerData, containerToEdit: container)
        }
    }

    // Behåll onDelete för EditButton
    func deleteContainer(at offsets: IndexSet) {
        offsets.forEach { index in
            // Säkerställ att index är giltigt
            guard index < containerData.containerList.count else { return }
            let container = containerData.containerList[index]
            containerData.deleteContainer(container)
        }
    }

    // *** NYTT: Funktion för swipe-delete ***
    func deleteContainerAction(container: Container) {
        containerData.deleteContainer(container)
    }
    // *** SLUT NYTT ***
}
