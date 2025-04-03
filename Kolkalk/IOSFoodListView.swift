// Kolkalk/IOSFoodListView.swift

import SwiftUI

// FoodItemRowView (oförändrad)
struct FoodItemRowView: View {
    let food: FoodItem
    var toggleAction: () -> Void
    var editAction: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(food.name).font(.headline)
                Text("\(food.carbsPer100g ?? 0, specifier: "%.1f") gk / 100g").font(.caption).foregroundColor(.gray)
            }
            Spacer()
            Button(action: toggleAction) {
                Image(systemName: food.isFavorite ? "heart.fill" : "heart")
                    .foregroundColor(food.isFavorite ? .red : .gray)
                    .imageScale(.large)
                    .padding(.leading, 5)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            editAction()
        }
    }
}


struct IOSFoodListView: View {
    @StateObject var foodData: FoodData_iOS
    @State private var showingAddSheet = false
    @State private var itemToEdit: FoodItem? = nil
    @State private var searchText: String = ""
    @State private var showFavoritesOnly: Bool = UserDefaults.standard.bool(forKey: "showFavoritesOnly_iOS")
    @State private var showingDeleteConfirmation = false

    private static var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()

    var filteredFoodList: [FoodItem] {
        var list = foodData.foodList
        if showFavoritesOnly {
            list = list.filter { $0.isFavorite }
        }
        if !searchText.isEmpty {
            list = list.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
        return list
    }

    var body: some View {
        ZStack {
            List {
                Toggle("Visa endast favoriter", isOn: $showFavoritesOnly)
                     // *** UPPDATERAD onChange SYNTAX ***
                     // Använder här closuren med två parametrar (newValue behövs)
                     .onChange(of: showFavoritesOnly) { oldValue, newValue in
                         UserDefaults.standard.set(newValue, forKey: "showFavoritesOnly_iOS")
                         print("Saved showFavoritesOnly to UserDefaults: \(newValue)")
                     }

                ForEach(filteredFoodList) { food in
                    FoodItemRowView(
                        food: food,
                        toggleAction: {
                            var updatedFood = food
                            updatedFood.isFavorite.toggle()
                            foodData.updateFoodItem(updatedFood)
                        },
                        editAction: {
                            itemToEdit = food
                        }
                    )
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            foodData.deleteFoodItem(withId: food.id)
                        } label: { Label("Ta bort", systemImage: "trash") }
                    }
                    .swipeActions(edge: .leading) {
                         Button {
                             itemToEdit = food
                         } label: {
                             Label("Redigera", systemImage: "pencil")
                         }
                         .tint(.blue)
                     }
                }

                if !foodData.foodList.isEmpty {
                     Button("Radera alla livsmedel", role: .destructive) { showingDeleteConfirmation = true }
                }

                // Status Section (oförändrad)
                Section {
                    HStack {
                        if foodData.isLoading {
                            ProgressView().padding(.trailing, 5)
                            Text("Synkroniserar...").foregroundColor(.secondary)
                        } else if let error = foodData.lastSyncError {
                            Image(systemName: "exclamationmark.icloud.fill").foregroundColor(.red)
                            Text("Synkfel").foregroundColor(.secondary)
                                .onTapGesture { print("Sync Error Details: \(error.localizedDescription)") }
                        } else if let syncTime = foodData.lastSyncTime {
                            Image(systemName: "checkmark.icloud.fill").foregroundColor(.green)
                            Text("Synkad: \(syncTime, formatter: Self.timeFormatter)").foregroundColor(.secondary)
                        } else {
                            Image(systemName: "icloud.slash").foregroundColor(.gray)
                            Text("Väntar på synk...").foregroundColor(.secondary)
                        }
                        Spacer()
                        Button { foodData.loadFoodListFromCloudKit() } label: { Image(systemName: "arrow.clockwise") }
                            .disabled(foodData.isLoading)
                    }
                    .font(.caption)
                }

            } // Slut på List

            // Loading indicator (oförändrad)
            if foodData.isLoading && foodData.foodList.isEmpty {
                 ProgressView("Laddar livsmedel...") // ... etc ...
             }

        }
        .searchable(text: $searchText, prompt: "Sök livsmedel")
        .navigationTitle("Livsmedel")
        .toolbar { // Oförändrad
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    itemToEdit = nil
                    showingAddSheet = true
                } label: { Image(systemName: "plus") }
            }
            ToolbarItem(placement: .navigationBarLeading) { EditButton() }
        }
        // Blad för "Lägg till" (oförändrad)
        .sheet(isPresented: $showingAddSheet) {
            NavigationView {
                 IOSAddEditFoodItemView(foodData: foodData, foodToEdit: nil)
            }
        }
        // Blad för "Redigera" (oförändrad)
        .sheet(item: $itemToEdit) { currentItemToEdit in
            NavigationView {
                 IOSAddEditFoodItemView(foodData: foodData, foodToEdit: currentItemToEdit)
            }
        }
        .confirmationDialog( // Oförändrad
             "Radera Alla",
             isPresented: $showingDeleteConfirmation,
             titleVisibility: .visible
         ) {
             Button("Radera alla livsmedel", role: .destructive) { foodData.deleteAllFoodItems() }
             Button("Avbryt", role: .cancel) {}
         } message: {
             Text("Är du säker på att du vill radera alla livsmedel? Detta kan inte ångras och påverkar alla dina enheter.")
         }
    }
}
