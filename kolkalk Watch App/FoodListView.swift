// Kolkalk.zip/kolkalk Watch App/FoodListView.swift

import SwiftUI

// List of available food items
struct FoodListView: View {
    @ObservedObject var plate: Plate // Behövs plate här? Troligen inte direkt.
    // *** ÄNDRING: Ta emot FoodData som ObservedObject ***
    @ObservedObject var foodData: FoodData
    @Binding var navigationPath: NavigationPath
    var isEmptyAndAdd: Bool

    @State private var searchText: String = ""
    @State private var showDeleteConfirmation = false
    // Initialize showFavoritesOnly from UserDefaults
    @State private var showFavoritesOnly: Bool = UserDefaults.standard.bool(forKey: "showFavoritesOnly") // Behåll separat för klockan

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
         // Sortering sker nu i CloudKit-queryn eller i FoodData efter uppdatering
        return list
    }

    var body: some View {
        // Använd ScrollViewReader för att kunna scrolla programmatiskt
         ScrollViewReader { scrollProxy in
            List {
                // Toggle button to show only favorites
                Toggle(isOn: $showFavoritesOnly) {
                    Text("Visa endast favoriter")
                }
                .id("favoritesToggle") // Ge ID för att kunna scrolla hit
                // Save the toggle state when it changes
                .onChange(of: showFavoritesOnly) { newValue in // Använd nya syntaxen
                    UserDefaults.standard.set(newValue, forKey: "showFavoritesOnly")
                }

                // Search field
                TextField("Sök", text: $searchText)
                    .id("searchField") // Assign ID

                // "Calculator" button under the search field
                Button(action: {
                    navigationPath.append(Route.calculator(shouldEmptyPlate: isEmptyAndAdd)) // Pass isEmptyAndAdd
                }) {
                    HStack {
                        Spacer()
                        Label("Kalkylator", systemImage: "plus.forwardslash.minus") // Ikon för kalkylator
                            .foregroundColor(.blue)
                        Spacer()
                    }
                }

                // *** ÄNDRING: Använd indices för ForEach för att kunna ge ID till första ***
                if !filteredFoodList.isEmpty {
                    ForEach(filteredFoodList.indices, id: \.self) { index in
                        let food = filteredFoodList[index]
                        HStack {
                            Text(food.name)
                            Spacer()
                            Text("\(food.carbsPer100g ?? 0, specifier: "%.1f") gk/100g") // Mer info
                                .font(.caption) // Mindre text
                                .foregroundColor(.gray)
                            if food.isFavorite { // Visa hjärta för favoriter
                                 Image(systemName: "heart.fill")
                                     .foregroundColor(.pink)
                             }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Skicka med food-objektet till detaljvyn
                            navigationPath.append(Route.foodDetailView(food, shouldEmptyPlate: isEmptyAndAdd))
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteFood(food) // Anropa korrigerad funktion
                            } label: {
                                Label("Ta bort", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                navigationPath.append(Route.editFoodItem(food)) // Skicka med food-objektet
                            } label: {
                                Label("Redigera", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .id(index == 0 ? "firstFood" : nil) // ID för första objektet
                    }
                } else {
                    // Display message when the list is empty
                    Text(searchText.isEmpty ? "Listan är tom. Lägg till via '+'." : "Inga träffar på \"\(searchText)\".")
                        .foregroundColor(.gray)
                        .padding()
                }

                // Buttons to add or delete food items
                Button(action: {
                    navigationPath.append(Route.createNewFoodItem)
                }) {
                    HStack {
                        Spacer()
                         Label("Lägg till nytt livsmedel", systemImage: "plus") // Bättre label
                            .foregroundColor(.blue)
                        Spacer()
                    }
                }

                // Button to delete all food items
                if !foodData.foodList.isEmpty { // Visa bara om listan inte är tom
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
                         "Radera alla livsmedel?", // Tydligare titel
                         isPresented: $showDeleteConfirmation,
                         titleVisibility: .visible
                     ) {
                         Button("Radera alla", role: .destructive) { // Tydligare knapptext
                             deleteAllFoodItems() // Anropa korrigerad funktion
                         }
                         Button("Avbryt", role: .cancel) {} // Ingen action behövs för cancel
                     } message: {
                         // Meddelande för att förklara konsekvenserna
                         Text("Är du säker? Detta tar bort alla livsmedel från listan på alla dina enheter och kan inte ångras.")
                     }
                 }
            } // End List
            // Kommentera bort onAppear om listan laddas via prenumeration i FoodData
            // .onAppear {
            //    foodData.loadFoodList()
            // }
        } // End ScrollViewReader
        .navigationTitle(isEmptyAndAdd ? "-+ Livsmedel" : "Livsmedel") // Anpassa titeln vid behov
    }

    // *** ÄNDRING: Raderingsfunktioner anropar nu FoodData ***
    private func deleteFood(_ food: FoodItem) {
        foodData.deleteFoodItem(withId: food.id) // Anropa metoden i FoodData
        // --- Borttaget ---
        // if let index = foodData.foodList.firstIndex(where: { $0.id == food.id }) {
        //     foodData.foodList.remove(at: index)
        //     foodData.saveToUserDefaults() // Finns ej längre
        // }
        // --- Slut Borttaget ---
    }

    private func deleteAllFoodItems() {
        foodData.deleteAllFoodItems() // Anropa metoden i FoodData
        // --- Borttaget ---
        // DispatchQueue.main.async {
        //     // Remove only user-created food items
        //     foodData.foodList.removeAll(where: { $0.isDefault != true })
        //     foodData.saveToUserDefaults() // Finns ej längre
        //     searchText = ""
        //     showDeleteConfirmation = false
        // }
        // --- Slut Borttaget ---

         // Stäng bekräftelsedialogen (kan behöva flyttas in i FoodData om det tar tid)
         showDeleteConfirmation = false
         // Rensa sökfältet
         searchText = ""
    }
}
