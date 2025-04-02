// kolkalk Watch App/ChooseContainerView.swift

import SwiftUI

struct ChooseContainerView: View {
    @Binding var selectedWeight: String
    @Environment(\.dismiss) var dismiss
    @ObservedObject var containerData = WatchContainerData.shared

    var body: some View {
        NavigationView {
            Group { // Använd Group för att applicera modifierare på villkorligt innehåll
                if containerData.isLoading && containerData.containerList.isEmpty {
                    ProgressView("Laddar kärl...")
                } else if containerData.containerList.isEmpty {
                     Text("Inga kärl hittades.\nLägg till kärl i iOS-appen.")
                         .foregroundColor(.gray)
                         .multilineTextAlignment(.center)
                         .padding()
                } else {
                    List {
                        ForEach(containerData.containerList) { container in
                            Button(action: {
                                selectedWeight = String(container.weight)
                                dismiss()
                            }) {
                                HStack {
                                    if let imageData = container.imageData, let uiImage = UIImage(data: imageData) {
                                        Image(uiImage: uiImage)
                                            .resizable().scaledToFit().frame(width: 50, height: 50)
                                    } else {
                                        Image(systemName: "cylinder.split.1x2")
                                            .resizable().scaledToFit().frame(width: 40, height: 40).foregroundColor(.gray)
                                    }
                                    VStack(alignment: .leading) {
                                        Text(container.name).font(.headline)
                                        Text("\(container.weight, specifier: "%.0f") g").foregroundColor(.gray).font(.subheadline)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 5)
                            }
                        }
                    }
                } // Slut på else (isLoading/isEmpty)
            } // Slut på Group
            // *** FIX: Applicera navigationTitle HÄR, på Group som innehåller allt ***
            .navigationTitle("Välj Kärl")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
            }
        } // Slut NavigationView
    }
}
