import SwiftUI

// Lista över tillgängliga livsmedel
struct FoodListView: View {
    @ObservedObject var plate: Plate
    @ObservedObject var foodData: FoodData
    @Binding var navigationPath: NavigationPath
    var isEmptyAndAdd: Bool

    @State private var searchText: String = ""
    @State private var showDeleteConfirmation = false

    var filteredFoodList: [FoodItem] {
        if searchText.isEmpty {
            return foodData.foodList
        } else {
            return foodData.foodList.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
    }

    var body: some View {
        List {
            Section(header:
                TextField("Sök", text: $searchText)
                    .padding(5)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            ) {
                ForEach(filteredFoodList) { food in
                    HStack {
                        Text(food.name)
                        Spacer()
                        Text("\(food.carbsPer100g ?? 0, specifier: "%.1f")/100g")
                            .foregroundColor(.gray)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        navigationPath.append(Route.foodDetailView(food, shouldEmptyPlate: isEmptyAndAdd))
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteFood(food)
                        } label: {
                            Label("Ta bort", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            navigationPath.append(Route.editFoodItem(food))
                        } label: {
                            Label("Redigera", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }

                Button(action: {
                    navigationPath.append(Route.createNewFoodItem)
                }) {
                    HStack {
                        Spacer()
                        Text("Lägg till nytt livsmedel")
                            .foregroundColor(.blue)
                        Spacer()
                    }
                }

                // Lägger till en knapp för att ta bort alla livsmedel
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    HStack {
                        Spacer()
                        Text("Radera alla livsmedel")
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
                .alert(isPresented: $showDeleteConfirmation) {
                    Alert(
                        title: Text("Bekräfta radering"),
                        message: Text("Är du säker på att du vill ta bort alla livsmedel?"),
                        primaryButton: .destructive(Text("Ja")) {
                            deleteAllFoodItems()
                        },
                        secondaryButton: .cancel(Text("Avbryt"))
                    )
                }
            }
        }
        .navigationTitle(isEmptyAndAdd ? "-+l Livsmedel" : "Livsmedel")
    }

    private func deleteFood(_ food: FoodItem) {
        if let index = foodData.foodList.firstIndex(where: { $0.id == food.id }) {
            foodData.foodList.remove(at: index)
            foodData.saveToUserDefaults()
        }
    }

    private func deleteAllFoodItems() {
        foodData.foodList.removeAll() // Rensar alla livsmedel
        foodData.saveToUserDefaults() // Spara uppdateringarna
    }
}
