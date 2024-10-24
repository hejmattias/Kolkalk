//
//  AddEditContainerView.swift
//  Kolkalk
//
//  Created by Mattias Göransson on 2024-10-24.
//


// Kolkalk/AddEditContainerView.swift

import SwiftUI

struct AddEditContainerView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var containerData: ContainerData
    @State var name: String = ""
    @State var weightString: String = ""
    var containerToEdit: Container?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Namn")) {
                    TextField("Namn", text: $name)
                }

                Section(header: Text("Vikt (g)")) {
                    TextField("Vikt", text: $weightString)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle(containerToEdit == nil ? "Lägg till Kärl" : "Redigera Kärl")
            .navigationBarItems(
                leading: Button("Avbryt") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Spara") {
                    saveContainer()
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(name.isEmpty || weightString.isEmpty)
            )
            .onAppear {
                if let container = containerToEdit {
                    name = container.name
                    weightString = String(container.weight)
                }
            }
        }
    }

    func saveContainer() {
        guard let weight = Double(weightString.replacingOccurrences(of: ",", with: ".")) else { return }

        if let container = containerToEdit {
            var updatedContainer = container
            updatedContainer.name = name
            updatedContainer.weight = weight
            containerData.updateContainer(updatedContainer)
        } else {
            let newContainer = Container(name: name, weight: weight)
            containerData.addContainer(newContainer)
        }
    }
}
