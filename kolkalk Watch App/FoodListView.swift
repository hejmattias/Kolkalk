import SwiftUI

struct FoodListView: View {
    @ObservedObject var plate: Plate
    @ObservedObject var foodData: FoodData
    @Binding var navigationPath: NavigationPath
    var isEmptyAndAdd: Bool

    @State private var searchText: String = ""
    @State private var showDeleteConfirmation = false
    @State private var showFavoritesOnly: Bool = UserDefaults.standard.bool(forKey: "showFavoritesOnly")

    private var favoritesBinding: Binding<Bool> {
        Binding(
            get: { self.showFavoritesOnly },
            set: { newValue in
                self.showFavoritesOnly = newValue
                UserDefaults.standard.set(newValue, forKey: "showFavoritesOnly")
                print("WatchOS UserDefaults saved showFavoritesOnly: \(newValue)")
            }
        )
    }

    private static var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    var filteredFoodList: [FoodItem] {
        var list = foodData.foodList
        if showFavoritesOnly { list = list.filter { $0.isFavorite } }
        if !searchText.isEmpty { list = list.filter { $0.name.lowercased().contains(searchText.lowercased()) } }
        return list
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ZStack {
                List {
                    // Sökfält (göms med scroll)
                    TextField("Sök", text: $searchText)
                        .id("searchField")

                    // --- Här har vi tagit bort "Color.clear"-raden! ---

                    // Kalkylator-knapp i stil med livsmedelsraderna
                    Button(action: {
                        navigationPath.append(Route.calculator(shouldEmptyPlate: isEmptyAndAdd))
                    }) {
                        HStack {
                            Text("Kalkylator")
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "plus.forwardslash.minus")
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .id("calculatorButton")

                    // Livsmedel-listan
                    if !filteredFoodList.isEmpty {
                        ForEach(filteredFoodList.indices, id: \.self) { index in
                            let food = filteredFoodList[index]
                            HStack {
                                Text(food.name)
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(food.carbsPer100g ?? 0, specifier: "%.1f") gk/100g")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                if food.isFavorite {
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(.pink)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                navigationPath.append(Route.foodDetailView(food, shouldEmptyPlate: isEmptyAndAdd))
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { deleteFood(food) } label: { Label("Ta bort", systemImage: "trash") }
                            }
                            .swipeActions(edge: .leading) {
                                Button { navigationPath.append(Route.editFoodItem(food)) } label: { Label("Redigera", systemImage: "pencil") }
                                    .tint(.blue)
                            }
                            .id(index == 0 ? "firstFoodItem" : nil)
                        }
                    } else {
                        Text(searchText.isEmpty ? "Listan är tom. Lägg till via '+'." : "Inga träffar på \"\(searchText)\".")
                            .foregroundColor(.gray)
                            .padding()
                    }

                    // Lägg till nytt livsmedel-knapp
                    Button(action: {
                        navigationPath.append(Route.createNewFoodItem)
                    }) {
                        HStack {
                            Spacer()
                            Label("Lägg till nytt livsmedel", systemImage: "plus")
                                .foregroundColor(.blue)
                            Spacer()
                        }
                    }

                    // Radera alla livsmedel-knapp (om listan inte är tom)
                    if !foodData.foodList.isEmpty {
                        Button(action: { showDeleteConfirmation = true }) {
                            HStack {
                                Spacer()
                                Text("Radera alla livsmedel")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                        .confirmationDialog(
                            "Radera alla livsmedel?",
                            isPresented: $showDeleteConfirmation,
                            titleVisibility: .visible
                        ) {
                            Button("Radera alla", role: .destructive) { deleteAllFoodItems() }
                            Button("Avbryt", role: .cancel) {}
                        } message: {
                            Text("Är du säker? Detta tar bort alla livsmedel från listan på alla dina enheter och kan inte ångras.")
                        }
                    }

                    Toggle(isOn: favoritesBinding) {
                        Text("Visa endast favoriter")
                    }
                    .id("favoritesToggle")

                    // Statussektion (längst ner)
                    Section {
                        HStack {
                            if foodData.isLoading {
                                ProgressView().scaleEffect(0.8)
                                Text("Synkar...")
                            } else if foodData.lastSyncError != nil {
                                Image(systemName: "exclamationmark.icloud").foregroundColor(.red)
                                Text("Synkfel")
                            } else if let syncTime = foodData.lastSyncTime {
                                Image(systemName: "checkmark.icloud").foregroundColor(.green)
                                Text("\(syncTime, formatter: Self.timeFormatter)")
                            } else {
                                Image(systemName: "icloud.slash").foregroundColor(.gray)
                                Text("Väntar")
                            }
                            Spacer()
                            Button { foodData.loadFoodListFromCloudKit() } label: { Image(systemName: "arrow.clockwise").imageScale(.small) }
                                .buttonStyle(.borderless)
                                .disabled(foodData.isLoading)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .listRowBackground(Color.clear)
                }
                .navigationTitle(isEmptyAndAdd ? "-+ Livsmedel" : "Livsmedel")
                .onAppear {
                    // Scrolla till "calculatorButton" för att säkert dölja sökrutan helt
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            scrollProxy.scrollTo("calculatorButton", anchor: .top)
                            print("WatchOS Scrolled to calculatorButton")
                        }
                    }
                }

                // Laddningsindikator över listan
                if foodData.isLoading && foodData.foodList.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.5))
                }
            }
        }
    }

    private func deleteFood(_ food: FoodItem) {
        foodData.deleteFoodItem(withId: food.id)
    }

    private func deleteAllFoodItems() {
        foodData.deleteAllFoodItems()
        searchText = ""
        showDeleteConfirmation = false
    }
}
