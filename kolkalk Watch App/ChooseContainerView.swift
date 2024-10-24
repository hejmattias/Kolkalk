// kolkalk Watch App/ChooseContainerView.swift

import SwiftUI

struct ChooseContainerView: View {
    @Binding var selectedWeight: String
    @Environment(\.dismiss) var dismiss

    @ObservedObject var containerData = WatchContainerData.shared

    var body: some View {
        NavigationView {
            List {
                ForEach(containerData.containerList) { container in
                    Button(action: {
                        selectedWeight = String(container.weight)
                        dismiss()
                    }) {
                        HStack {
                            if let imageData = container.imageData, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 50, height: 50)
                            } else {
                                // Placeholder-bild
                                Image(systemName: "photo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 50, height: 50)
                                    .foregroundColor(.gray)
                            }

                            VStack(alignment: .leading) {
                                Text(container.name)
                                    .font(.headline)
                                Text("\(container.weight, specifier: "%.0f") g")
                                    .foregroundColor(.gray)
                                    .font(.subheadline)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
            .navigationTitle("Välj Kärl")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                containerData.loadFromUserDefaults()
            }
        }
    }
}
