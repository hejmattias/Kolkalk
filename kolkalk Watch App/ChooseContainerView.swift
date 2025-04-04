// kolkalk Watch App/ChooseContainerView.swift

import SwiftUI

struct ChooseContainerView: View {
    @Binding var selectedWeight: String
    @Environment(\.dismiss) var dismiss
    @ObservedObject var containerData = WatchContainerData.shared

    // *** NYTT: Formatter för tid ***
    private static var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss" // Anpassa formatet vid behov
        return formatter
    }()
    // *** SLUT NYTT ***

    var body: some View {
        // Behåll NavigationView här eftersom vyn presenteras i ett .sheet
        NavigationView {
            // Använd ZStack för att kunna visa overlay vid laddning
            ZStack {
                // Använd VStack istället för Group för att lättare placera status längst ner
                VStack {
                    if containerData.isLoading && containerData.containerList.isEmpty {
                        // Visa centrerad ProgressView om listan är tom och laddar
                        Spacer()
                        ProgressView("Laddar kärl...")
                        Spacer()
                    } else if containerData.containerList.isEmpty {
                         // Visa meddelande om listan är tom
                         Spacer()
                         Text("Inga kärl hittades.\nLägg till kärl i iOS-appen.")
                             .foregroundColor(.gray)
                             .multilineTextAlignment(.center)
                             .padding()
                         Spacer()
                    } else {
                        // Visa listan om den inte är tom
                        List {
                            ForEach(containerData.containerList) { container in
                                Button(action: {
                                    selectedWeight = String(container.weight)
                                    dismiss()
                                }) {
                                    HStack {
                                        if let imageData = container.imageData, let uiImage = UIImage(data: imageData) {
                                            Image(uiImage: uiImage)
                                                .resizable().scaledToFit().frame(width: 40, height: 40) // Justerad storlek
                                                .cornerRadius(4)
                                        } else {
                                            Image(systemName: "cylinder.split.1x2")
                                                .resizable().scaledToFit().frame(width: 30, height: 30).foregroundColor(.gray) // Justerad storlek
                                                .padding(5)
                                                .background(Color(uiColor: .darkGray).opacity(0.5))
                                                .cornerRadius(4)
                                        }
                                        VStack(alignment: .leading) {
                                            Text(container.name).font(.headline)
                                            Text("\(container.weight, specifier: "%.0f") g").foregroundColor(.gray).font(.caption) // Mindre font för vikt
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 2) // Minskad padding
                                }
                            }
                        } // Slut List
                    } // Slut else (listan visas)

                    // *** NYTT: Status Section (alltid längst ner i VStack) ***
                    HStack {
                        if containerData.isLoading && !containerData.containerList.isEmpty { // Visa bara "Synkar..." om listan inte är tom
                             ProgressView().scaleEffect(0.8) // Mindre ProgressView
                             Text("Synkar...")
                         } else if containerData.lastSyncError != nil {
                             Image(systemName: "exclamationmark.icloud").foregroundColor(.red)
                             Text("Synkfel")
                         } else if let syncTime = containerData.lastSyncTime {
                             Image(systemName: "checkmark.icloud").foregroundColor(.green)
                             Text("\(syncTime, formatter: Self.timeFormatter)")
                         } else if !containerData.isLoading { // Visa bara "Väntar" om vi inte laddar
                             Image(systemName: "icloud.slash").foregroundColor(.gray)
                             Text("Väntar")
                         }
                        Spacer()
                        Button {
                            containerData.loadContainersFromCloudKit()
                        } label: {
                            Image(systemName: "arrow.clockwise").imageScale(.small)
                        }
                        .buttonStyle(.borderless) // Ta bort standardknappstilen
                        .disabled(containerData.isLoading)
                    }
                    .font(.caption) // Mindre font för status
                    .foregroundColor(.secondary)
                    .padding(.horizontal) // Lägg till padding horisontellt
                    .padding(.bottom, 5) // Lite utrymme nedåt
                    // *** SLUT NYTT ***

                } // Slut VStack
            } // Slut ZStack
            .navigationTitle("Välj Kärl") // Flyttad hit
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
            }
        } // Slut NavigationView
    }
}
