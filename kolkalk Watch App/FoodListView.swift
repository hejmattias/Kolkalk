import SwiftUI

// Lista över tillgängliga livsmedel
struct FoodListView: View {
    @ObservedObject var plate: Plate
    @ObservedObject var foodData: FoodData
    @Binding var navigationPath: NavigationPath
    var isEmptyAndAdd: Bool

    @State private var searchText: String = ""
    @State private var showDeleteConfirmation = false
    @State private var showFavoritesOnly: Bool = false // Ny State-variabel för favoritfilter

    var filteredFoodList: [FoodItem] {
        var list = foodData.foodList

        // Filtrera på favoriter om växlingen är på
        if showFavoritesOnly {
            list = list.filter { $0.isFavorite }
        }

        // Filtrera på söktext
        if !searchText.isEmpty {
            list = list.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }

        return list
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            List {
                // Växlingsknapp för att visa endast favoriter
                Toggle(isOn: $showFavoritesOnly) {
                    Text("Visa endast favoriter")
                }
                .id("favoritesToggle") // Tilldela ID för att kunna scrolla till den

                // Sökfältet
                TextField("Sök", text: $searchText)
                    .id("searchField") // Tilldela ID

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
                        .id(index == 0 ? "firstFood" : nil) // Tilldela ID till första posten
                    }
                }

                // Knappar för att lägga till eller radera livsmedel
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

                // Knapp för att radera alla livsmedel
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
            .onAppear {
                // Vänta tills listan har laddats, sedan scrolla till favoritväxlingen
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scrollProxy.scrollTo("favoritesToggle", anchor: .top)
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

