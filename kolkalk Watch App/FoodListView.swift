// Kolkalk.zip/kolkalk Watch App/FoodListView.swift

import SwiftUI

struct FoodListView: View {
    @ObservedObject var plate: Plate
    @ObservedObject var foodData: FoodData
    @Binding var navigationPath: NavigationPath
    var isEmptyAndAdd: Bool

    @State private var searchText: String = ""
    @State private var showDeleteConfirmation = false
    // Behåll @State, men vi skapar ett anpassat Binding nedan
    @State private var showFavoritesOnly: Bool = UserDefaults.standard.bool(forKey: "showFavoritesOnly")

    // *** NYTT: Anpassat Binding för att ersätta .onChange ***
    private var favoritesBinding: Binding<Bool> {
        Binding(
            get: { self.showFavoritesOnly },
            set: { newValue in
                self.showFavoritesOnly = newValue
                UserDefaults.standard.set(newValue, forKey: "showFavoritesOnly") // Spara vid ändring
                print("WatchOS UserDefaults saved showFavoritesOnly: \(newValue)") // För felsökning
            }
        )
    }
    // *** SLUT NYTT ***

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
         ScrollViewReader { scrollProxy in // ScrollViewReader behövs för att scrolla
             // Använd ZStack för att kunna visa laddningsindikator *över* listan
              ZStack {
                  List {
                      // *** START: ÖVRIGA LISTELEMENT (OFÖRÄNDRADE) ***
                       // *** ÄNDRING: Använder nu favoritesBinding ***
                       Toggle(isOn: favoritesBinding) {
                           Text("Visa endast favoriter")
                       }
                       .id("favoritesToggle")
                       // *** .onChange borttagen ***

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
                       .id("calculatorButton") // Ge ID för scroll-referens om nödvändigt

                       // Använd den filtrerade listan
                       if !filteredFoodList.isEmpty {
                           // *** Ge ForEach ett ID för att kunna scrolla förbi sektionen ovanför ***
                           Section { // Omslut ForEach med en Section om det behövs för scrollning
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
                                   // *** ID för att scrolla till första RADEN i listan ***
                                   .id(index == 0 ? "firstFoodItem" : nil)
                               }
                           } header: {
                               Text("Livsmedel").id("foodListHeader") // Header för sektionen, kan också få ID
                           }
                           // *** Slut ändring ForEach ***
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
                      // *** SLUT: ÖVRIGA LISTELEMENT ***

                      // *** STATUS HEADER (LIGGER KVAR LÄNGST NED) ***
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

                  } // End List
                  .navigationTitle(isEmptyAndAdd ? "-+ Livsmedel" : "Livsmedel")
                  // *** NYTT: .onAppear för att scrolla ***
                  .onAppear {
                      // Scrolla till första matvaran efter en kort fördröjning
                      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                          // Kontrollera att listan inte är tom innan scrollning
                          if !filteredFoodList.isEmpty {
                              withAnimation { // Lägg till animation om du vill
                                  scrollProxy.scrollTo("firstFoodItem", anchor: .top)
                                  print("WatchOS Scrolled to firstFoodItem") // För felsökning
                              }
                          } else {
                              print("WatchOS Food list is empty, cannot scroll.") // För felsökning
                          }
                      }
                  }
                  // *** SLUT NYTT ***

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
