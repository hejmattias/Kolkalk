//
//  ContainerListView.swift
//  Kolkalk
//
//  Created by Mattias Göransson on 2024-10-24.
//


// Kolkalk/ContainerListView.swift

import SwiftUI

struct ContainerListView: View {
    @ObservedObject var containerData = ContainerData.shared
    @State private var showingAddContainer = false
    @State private var editingContainer: Container?

    var body: some View {
        List {
            ForEach(containerData.containerList) { container in
                HStack {
                    Text(container.name)
                    Spacer()
                    Text("\(container.weight, specifier: "%.0f") g")
                        .foregroundColor(.gray)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    editingContainer = container
                }
            }
            .onDelete(perform: deleteContainer)
        }
        .navigationTitle("Kärl")
        .navigationBarItems(
            leading: EditButton(),
            trailing: Button(action: {
                showingAddContainer = true
            }) {
                Image(systemName: "plus")
            }
        )
        .sheet(isPresented: $showingAddContainer) {
            AddEditContainerView(containerData: containerData)
        }
        .sheet(item: $editingContainer) { container in
            AddEditContainerView(containerData: containerData, containerToEdit: container)
        }
    }

    func deleteContainer(at offsets: IndexSet) {
        offsets.forEach { index in
            let container = containerData.containerList[index]
            containerData.deleteContainer(container)
        }
    }
}
