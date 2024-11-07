// Kolkalk/AddEditContainerView.swift

import SwiftUI

struct AddEditContainerView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var containerData: ContainerData
    @State var name: String = ""
    @State var weightString: String = ""
    var containerToEdit: Container?

    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false

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

                Section(header: Text("Bild")) {
                    HStack {
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 100)
                        } else {
                            Text("Ingen bild vald")
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Button(action: {
                            showingImagePicker = true
                        }) {
                            Text("Välj bild")
                        }
                    }
                }
            }
            .navigationTitle(containerToEdit == nil ? "Lägg till Kärl" : "Redigera Kärl")
            .navigationBarItems(
                leading: Button("Avbryt") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Spara") {
                    saveContainer()
                }
                .disabled(name.isEmpty || weightString.isEmpty)
            )
            .onAppear {
                if let container = containerToEdit {
                    name = container.name
                    weightString = String(container.weight)
                    if let imageData = container.imageData, let uiImage = UIImage(data: imageData) {
                        selectedImage = uiImage
                        print("Bildstorlek: \(uiImage.size)") // För felsökning
                    } else {
                        print("Kunde inte ladda bilden.")
                    }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: $selectedImage)
            }
        }
    }

    func saveContainer() {
        guard let weight = Double(weightString.replacingOccurrences(of: ",", with: ".")) else { return }

        // Flytta bildbehandlingen till en bakgrundstråd
        DispatchQueue.global(qos: .userInitiated).async {
            var imageData: Data? = nil
            if let selectedImage = selectedImage {
                let resizedImage = selectedImage.resize(toWidth: 100) // Anpassa storleken vid behov
                imageData = resizedImage.jpegData(compressionQuality: 0.8)
            }

            // Uppdatera UI och spara data på huvudtråden
            DispatchQueue.main.async {
                if let container = containerToEdit {
                    var updatedContainer = container
                    updatedContainer.name = name
                    updatedContainer.weight = weight
                    updatedContainer.imageData = imageData
                    containerData.updateContainer(updatedContainer)
                } else {
                    let newContainer = Container(name: name, weight: weight, imageData: imageData)
                    containerData.addContainer(newContainer)
                }

                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

// Uppdaterad extension för att ändra storlek på bilder
extension UIImage {
    func resize(toWidth width: CGFloat) -> UIImage {
        guard size.width > 0 && size.height > 0 else {
            print("Fel: Bildens storlek är 0")
            return self
        }
        let scaleFactor = width / size.width
        let newHeight = size.height * scaleFactor
        let canvasSize = CGSize(width: width, height: newHeight)
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        self.draw(in: CGRect(origin: .zero, size: canvasSize))
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }
}
