// kolkalk Watch App/ChooseContainerView.swift

import SwiftUI

struct ChooseContainerView: View {
    @Binding var selectedWeight: String
    @Environment(\.dismiss) var dismiss

    @ObservedObject var containerData = WatchContainerData.shared

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(containerData.containerList) { container in
                        Button(action: {
                            selectedWeight = String(container.weight)
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "square")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 50, height: 50)
                                Text(container.name)
                                    .font(.headline)
                                Spacer()
                                Text("\(container.weight, specifier: "%.0f") g")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Välj Kärl")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            containerData.loadFromUserDefaults()
        }
    }
}

