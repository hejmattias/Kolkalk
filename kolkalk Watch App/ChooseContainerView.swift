import SwiftUI

struct Container: Identifiable {
    let id = UUID()
    let name: String
    let imageName: String
    let weight: Double
}

struct ChooseContainerView: View {
    @Binding var selectedWeight: String
    @Environment(\.dismiss) var dismiss

    let containers: [Container] = [
        Container(name: "Litet glas", imageName: "smallGlass", weight: 50.0),
        Container(name: "Måttkopp", imageName: "measuringCup", weight: 100.0),
        Container(name: "Stor skål", imageName: "largeBowl", weight: 200.0),
        // Lägg till fler kärl vid behov
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(containers) { container in
                        Button(action: {
                            selectedWeight = String(container.weight)
                            dismiss()
                        }) {
                            HStack {
                                Image(container.imageName)
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
    }
}
