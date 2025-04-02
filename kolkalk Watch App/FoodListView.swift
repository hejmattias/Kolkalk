// Kolkalk.zip/kolkalk Watch App/FoodListView.swift

import SwiftUI

// List of available food items
struct FoodListView: View {
    @ObservedObject var plate: Plate
    @ObservedObject var foodData: FoodData // Använder nu den uppdaterade FoodData
    @Binding var navigationPath: NavigationPath
    var isEmptyAndAdd: Bool

    @State private var searchText: String = ""
    @State private var showDeleteConfirmation = false
    @State private var showFavoritesOnly: Bool = UserDefaults.standard.bool(forKey: "showFavoritesOnly")

    var filteredFoodList: [FoodItem] {
        // Filtreringslogiken är oförändrad, men använder den cachade/uppdaterade foodList
        var list = foodData.foodList

        if showFavoritesOnly {
            list = list.filter { $0.isFavorite }
        }

        if !searchText.isEmpty {
            list = list.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
        // Sortering sker nu i FoodData vid laddning/modifiering
        return list
    }

    var body: some View {
        // Använd ScrollViewReader för att kunna scrolla programmatiskt
         ScrollViewReader { scrollProxy in
             // *** NYTT: Kontrollera isLoading ***
             if foodData.isLoading && foodData.foodList.isEmpty {
                 // Visa bara ProgressView om listan är helt tom OCH vi laddar från CloudKit
                 ProgressView("Laddar livsmedel...")
                     .navigationTitle("Laddar...")
             } else {
                 // *** Visa listan (antingen från cache eller uppdaterad) ***
                 List {
                     Toggle(isOn: $showFavoritesOnly) {
                         Text("Visa endast favoriter")
                     }
                     .id("favoritesToggle")
                     .onChange(of: showFavoritesOnly) { newValue in
                         UserDefaults.standard.set(newValue, forKey: "showFavoritesOnly")
                     }

                     TextField("Sök", text: $searchText)
                         .id("searchField")

                     Button(action: {
                         navigationPath.append(Route.calculator(shouldEmptyPlate: isEmptyAndAdd))
                     }) {
                         HStack {
                             Spacer()
                             Label("Kalkylator", systemImage: "plus.forwardslash.minus")
                                 .foregroundColor(.blue)
                             Spacer()
                         }
                     }

                     // Använd den filtrerade listan
                     if !filteredFoodList.isEmpty {
                         ForEach(filteredFoodList.indices, id: \.self) { index in
                             let food = filteredFoodList[index]
                             HStack {
                                 Text(food.name)
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
                                 Button(role: .destructive) {
                                     deleteFood(food) // Anropar nu den uppdaterade funktionen
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
                             .id(index == 0 ? "firstFood" : nil)
                         }
                     } else {
                         // Visa meddelande när listan är tom *efter* laddning
                         Text(searchText.isEmpty ? "Listan är tom. Lägg till via '+'." : "Inga träffar på \"\(searchText)\".")
                             .foregroundColor(.gray)
                             .padding()
                     }

                     // Knappar för att lägga till / radera
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

                     if !foodData.foodList.isEmpty { // Använd foodData.foodList för att se om något finns alls
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
                          .confirmationDialog(
                              "Radera alla livsmedel?",
                              isPresented: $showDeleteConfirmation,
                              titleVisibility: .visible
                          ) {
                              Button("Radera alla", role: .destructive) {
                                  deleteAllFoodItems() // Anropar nu den uppdaterade funktionen
                              }
                              Button("Avbryt", role: .cancel) {}
                          } message: {
                              Text("Är du säker? Detta tar bort alla livsmedel från listan på alla dina enheter och kan inte ångras.")
                          }
                      }
                 } // End List
                 // Sätt titeln när listan visas
                 .navigationTitle(isEmptyAndAdd ? "-+ Livsmedel" : "Livsmedel")
             } // End else (isLoading)
        } // End ScrollViewReader
        // .onAppear behövs inte längre för att ladda listan här
    }

    // Dessa funktioner anropar nu de uppdaterade i FoodData
    private func deleteFood(_ food: FoodItem) {
        foodData.deleteFoodItem(withId: food.id)
    }

    private func deleteAllFoodItems() {
        foodData.deleteAllFoodItems()
        // Rensa sökfält etc. lokalt
        searchText = ""
        showDeleteConfirmation = false
    }
}
