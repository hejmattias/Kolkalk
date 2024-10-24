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
                        Text("\(container.weight, specifier: "%.0f") g")
                            .foregroundColor(.gray)
                    }
                    Spacer()
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

