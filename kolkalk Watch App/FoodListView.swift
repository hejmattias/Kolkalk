import SwiftUI

// List of available food items
struct FoodListView: View {
    @ObservedObject var plate: Plate
    @ObservedObject var foodData: FoodData
    @Binding var navigationPath: NavigationPath
    var isEmptyAndAdd: Bool

    @State private var searchText: String = ""
    @State private var showDeleteConfirmation = false
    @State private var showFavoritesOnly: Bool = false // State variable for favorite filter

    var filteredFoodList: [FoodItem] {
        var list = foodData.foodList

        // Filter on favorites if the toggle is on
        if showFavoritesOnly {
            list = list.filter { $0.isFavorite }
        }

        // Filter on search text
        if !searchText.isEmpty {
            list = list.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }

        return list
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            List {
                // Toggle button to show only favorites
                Toggle(isOn: $showFavoritesOnly) {
                    Text("Visa endast favoriter")
                }
                .id("favoritesToggle") // Assign ID to scroll to it

                // Search field
                TextField("Sök", text: $searchText)
                    .id("searchField") // Assign ID

                if !filteredFoodList.isEmpty {
                    ForEach(filteredFoodList.indices, id: \.self) { index in
                        let food = filteredFoodList[index]
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
                        .id(index == 0 ? "firstFood" : nil) // Assign ID to the first item
                    }
                } else {
                    // Display message when the list is empty
                    Text("Inga livsmedel att visa")
                        .foregroundColor(.gray)
                }

                // Buttons to add or delete food items
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

                // Button to delete all food items
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
                // Use confirmationDialog instead of alert
                .confirmationDialog(
                    "Bekräfta radering",
                    isPresented: $showDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Ta bort alla livsmedel", role: .destructive) {
                        deleteAllFoodItems()
                    }
                    Button("Avbryt", role: .cancel) {
                        // Optionally reset any state if needed
                    }
                } message: {
                    Text("Är du säker på att du vill ta bort alla livsmedel?")
                }
            }
            .onAppear {
                // Wait until the list has loaded, then scroll to the favorite toggle
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if !filteredFoodList.isEmpty {
                        scrollProxy.scrollTo("firstFood", anchor: .top)
                    }
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
        DispatchQueue.main.async {
            // Remove only user-created food items
            foodData.foodList.removeAll(where: { $0.isDefault != true })
            foodData.saveToUserDefaults() // Save the updates

            // Reset filters to show default foods
            searchText = ""
            showFavoritesOnly = false

            // Close the delete confirmation alert
            showDeleteConfirmation = false
        }
    }
}
