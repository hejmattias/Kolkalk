// Kolkalk.zip/kolkalk Watch App/FoodListView.swift

import SwiftUI

struct FoodListView: View {
    @ObservedObject var plate: Plate
    @ObservedObject var foodData: FoodData
    @Binding var navigationPath: NavigationPath
    var isEmptyAndAdd: Bool

    @State private var searchText: String = ""
    @State private var showDeleteConfirmation = false
    @State private var showFavoritesOnly: Bool = UserDefaults.standard.bool(forKey: "showFavoritesOnly")

    // Formatter för tidvisning (enklare för klockan)
    private static var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss" // Enkelt format
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
             // Använd ZStack för att kunna visa laddningsindikator *över* listan
              ZStack {
                  List {
                      // *** NY STATUS HEADER ***
                       Section {
                           HStack {
                               if foodData.isLoading {
                                   ProgressView()
                                       .scaleEffect(0.8) // Mindre snurra
                                   Text("Synkar...")
                               } else if foodData.lastSyncError != nil {
                                   Image(systemName: "exclamationmark.icloud")
                                       .foregroundColor(.red)
                                   Text("Synkfel")
                               } else if let syncTime = foodData.lastSyncTime {
                                   Image(systemName: "checkmark.icloud")
                                       .foregroundColor(.green)
                                   Text("\(syncTime, formatter: Self.timeFormatter)")
                               } else {
                                   Image(systemName: "icloud.slash")
                                       .foregroundColor(.gray)
                                   Text("Väntar")
                               }
                               Spacer()
                               Button {
                                  foodData.loadFoodListFromCloudKit() // Manuell refresh
                               } label: {
                                  Image(systemName: "arrow.clockwise")
                                      .imageScale(.small) // Mindre ikon
                               }
                               .buttonStyle(.borderless) // Ta bort ram runt knappen
                               .disabled(foodData.isLoading) // Inaktivera vid synk
                           }
                           .font(.caption) // Mindre text i headern
                           .foregroundColor(.secondary) // Grå text
                       } header: {
                           // Ingen text behövs i själva header-labeln
                       }
                       .listRowBackground(Color.clear) // Försök ta bort bakgrunden på sektionen
                       // *** SLUT STATUS HEADER ***


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
                               // ... (oförändrad item-visning) ...
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
                                .id(index == 0 ? "firstFood" : nil)
                           }
                       } else {
                           Text(searchText.isEmpty ? "Listan är tom. Lägg till via '+'." : "Inga träffar på \"\(searchText)\".")
                               .foregroundColor(.gray)
                               .padding()
                       }

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

                       if !foodData.foodList.isEmpty {
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
                                    deleteAllFoodItems()
                                }
                                Button("Avbryt", role: .cancel) {}
                            } message: {
                                Text("Är du säker? Detta tar bort alla livsmedel från listan på alla dina enheter och kan inte ångras.")
                            }
                        }
                  } // End List
                  .navigationTitle(isEmptyAndAdd ? "-+ Livsmedel" : "Livsmedel")

                  // Visa laddningsindikator över listan vid initial laddning
                   if foodData.isLoading && foodData.foodList.isEmpty {
                       ProgressView()
                           .frame(maxWidth: .infinity, maxHeight: .infinity)
                           .background(Color.black.opacity(0.5)) // Gör bakgrunden mörkare
                   }

              } // End ZStack
        } // End ScrollViewReader
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
