import SwiftUI

struct FoodListView: View {
    @ObservedObject var plate: Plate
    @ObservedObject var foodData: FoodData
    @Binding var navigationPath: NavigationPath
    var isEmptyAndAdd: Bool

    @State private var searchText: String = ""
    @State private var showDeleteConfirmation = false
    @State private var showFavoritesOnly: Bool = UserDefaults.standard.bool(forKey: "showFavoritesOnly")

    // Extern sökning
    @State private var externalResults: [FoodItem] = []
    @State private var isSearchingExternal: Bool = false
    @State private var externalError: String? = nil
    @State private var searchTask: Task<Void, Never>? = nil

    // NYTT: Toggle för “Visa endast beräknat livsmedel”
    @State private var showCalculatedOnly: Bool = false

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

    // NYTT: Hjälp för att veta om vi kan visa togglen (endast om någon post har flagga)
    private var canFilterCalculated: Bool {
        externalResults.contains(where: { $0.isCalculatedFromSLV != nil })
    }

    // NYTT: Resultat som faktiskt visas (ev. filtrerade på “beräknat”)
    private var displayedExternalResults: [FoodItem] {
        if canFilterCalculated && showCalculatedOnly {
            return externalResults.filter { $0.isCalculatedFromSLV == true }
        } else {
            return externalResults
        }
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ZStack {
                List {
                    // Sökfält (göms med scroll)
                    TextField("Sök", text: $searchText)
                        .id("searchField")
                        .onChange(of: searchText) { _, newValue in
                            triggerExternalSearch(for: newValue)
                        }

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

                    // Lokala livsmedel
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
                        Text(searchText.isEmpty ? "Listan är tom. Lägg till via '+'." : "Inga lokala träffar på \"\(searchText)\".")
                            .foregroundColor(.gray)
                            .padding()
                    }

                    // Externa träffar (Livsmedelsverket)
                    if !searchText.isEmpty {
                        // NYTT: Visa antal träffar i rubriken
                        Section(header: HStack {
                            Text("Från Livsmedelsverket (\(displayedExternalResults.count))")
                            if isSearchingExternal { Spacer(); ProgressView().scaleEffect(0.7) }
                        }) {
                            // NYTT: Visa toggle för “Visa endast beräknat livsmedel” om flaggan finns på någon post
                            if canFilterCalculated {
                                Toggle(isOn: $showCalculatedOnly.animation()) {
                                    Text("Visa endast beräknat livsmedel")
                                }
                            }

                            if let error = externalError {
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .lineLimit(6)
                            } else if displayedExternalResults.isEmpty {
                                Text(isSearchingExternal ? "Söker..." : "Inga externa träffar.")
                                    .foregroundColor(.gray)
                            } else {
                                ForEach(displayedExternalResults.indices, id: \.self) { index in
                                    let extFood = displayedExternalResults[index]
                                    HStack {
                                        Text(extFood.name)
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text("\(extFood.carbsPer100g ?? 0, specifier: "%.1f") gk/100g")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Image(systemName: "network")
                                            .foregroundColor(.blue)
                                        // Valfri ikon om posten är beräknad
                                        if extFood.isCalculatedFromSLV == true {
                                            Image(systemName: "function")
                                                .foregroundColor(.teal)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        navigationPath.append(Route.foodDetailView(extFood, shouldEmptyPlate: isEmptyAndAdd))
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button {
                                            saveExternalFood(extFood)
                                        } label: {
                                            Label("Spara", systemImage: "square.and.arrow.down")
                                        }
                                        .tint(.green)
                                    }
                                }
                            }
                        }
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            scrollProxy.scrollTo("calculatorButton", anchor: .top)
                            print("WatchOS Scrolled to calculatorButton")
                        }
                    }
                }

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

    private func saveExternalFood(_ item: FoodItem) {
        foodData.addFoodItem(item)
        print("Saved external item to list: \(item.name)")
    }

    private func triggerExternalSearch(for text: String) {
        searchTask?.cancel()
        externalError = nil

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            externalResults = []
            isSearchingExternal = false
            return
        }

        isSearchingExternal = true

        searchTask = Task { [currentQuery = trimmed] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }

            do {
                let api = LivsmedelsverketAPIClient()
                let results = try await api.searchFoods(query: currentQuery, limit: 25)

                // Filtrera bort dubbletter som redan finns lokalt (baserat på namn)
                let localNames = Set(foodData.foodList.map { $0.name.lowercased() })
                let filteredForDuplicates = results.filter { !localNames.contains($0.name.lowercased()) }

                // Variant A: behåll alla som innehåller query (diakritik/skiftlägesokänsligt)
                let normalizedQuery = normalize(currentQuery)
                let lightlyFiltered = filteredForDuplicates.filter { item in
                    normalize(item.name).contains(normalizedQuery)
                }

                if !Task.isCancelled {
                    await MainActor.run {
                        self.externalResults = lightlyFiltered
                        self.isSearchingExternal = false
                        self.externalError = nil
                        // Nollställ togglen när nya resultat kommer
                        self.showCalculatedOnly = false
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.externalResults = []
                        self.isSearchingExternal = false
                        self.externalError = error.localizedDescription
                    }
                }
            }
        }
    }

    // MARK: - Normalisering (diakritik- och skiftlägesokänslig)
    private func normalize(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}

