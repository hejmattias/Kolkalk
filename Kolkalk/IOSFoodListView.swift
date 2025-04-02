// Kolkalk/IOSFoodListView.swift

import SwiftUI

struct IOSFoodListView: View {
    @ObservedObject var foodData: FoodData_iOS
    @State private var showingAddEditSheet = false
    @State private var foodToEdit: FoodItem? = nil
    @State private var searchText: String = ""
    @State private var showFavoritesOnly: Bool = UserDefaults.standard.bool(forKey: "showFavoritesOnly_iOS")
    @State private var showingDeleteConfirmation = false

    // Formatter för tidvisning
    private static var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()

    var filteredFoodList: [FoodItem] {
        var list = foodData.foodList
        if showFavoritesOnly { list = list.filter { $0.isFavorite } }
        if !searchText.isEmpty { list = list.filter { $0.name.lowercased().contains(searchText.lowercased()) } }
        return list
    }

    var body: some View {
        ZStack {
            List {
                Toggle("Visa endast favoriter", isOn: $showFavoritesOnly)
                     .onChange(of: showFavoritesOnly) { newValue in
                         UserDefaults.standard.set(newValue, forKey: "showFavoritesOnly_iOS")
                     }

                ForEach(filteredFoodList) { food in
                    // ... (oförändrad item-visning) ...
                    HStack {
                        VStack(alignment: .leading) {
                            Text(food.name).font(.headline)
                            Text("\(food.carbsPer100g ?? 0, specifier: "%.1f") gk / 100g").font(.caption).foregroundColor(.gray)
                        }
                        Spacer()
                        if food.isFavorite { Image(systemName: "heart.fill").foregroundColor(.red) }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { foodToEdit = food; showingAddEditSheet = true }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { foodData.deleteFoodItem(withId: food.id) } label: { Label("Ta bort", systemImage: "trash") }
                    }
                    .swipeActions(edge: .leading) {
                         Button { foodToEdit = food; showingAddEditSheet = true } label: { Label("Redigera", systemImage: "pencil") }.tint(.blue)
                     }
                }

                if !foodData.foodList.isEmpty {
                     Button("Radera alla livsmedel", role: .destructive) { showingDeleteConfirmation = true }
                }

                // *** NY STATUSSEKTION ***
                Section {
                    HStack {
                        if foodData.isLoading {
                            ProgressView()
                                .padding(.trailing, 5)
                            Text("Synkroniserar...")
                                .foregroundColor(.secondary)
                        } else if let error = foodData.lastSyncError {
                            Image(systemName: "exclamationmark.icloud.fill")
                                .foregroundColor(.red)
                            Text("Synkfel")
                                .foregroundColor(.secondary)
                                .onTapGesture { // Gör felet tappbart för att visa detaljer?
                                     print("Sync Error Details: \(error.localizedDescription)")
                                     // Du kan visa en Alert här om du vill
                                 }
                        } else if let syncTime = foodData.lastSyncTime {
                            Image(systemName: "checkmark.icloud.fill")
                                .foregroundColor(.green)
                            Text("Synkad: \(syncTime, formatter: Self.timeFormatter)")
                                .foregroundColor(.secondary)
                        } else {
                            Image(systemName: "icloud.slash")
                                .foregroundColor(.gray)
                            Text("Väntar på synk...")
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button {
                           foodData.loadFoodListFromCloudKit() // Manuell refresh-knapp
                        } label: {
                           Image(systemName: "arrow.clockwise")
                        }
                        .disabled(foodData.isLoading) // Inaktivera vid synk
                    }
                    .font(.caption) // Gör texten mindre
                }
                // *** SLUT STATUSSEKTION ***

            } // Slut på List

            if foodData.isLoading && foodData.foodList.isEmpty {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemBackground).opacity(0.6))
            }

        }
        .searchable(text: $searchText, prompt: "Sök livsmedel")
        .navigationTitle("Livsmedel")
        .toolbar { /* Toolbar oförändrad */
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { foodToEdit = nil; showingAddEditSheet = true } label: { Image(systemName: "plus") }
            }
            ToolbarItem(placement: .navigationBarLeading) { EditButton() }
        }
        .sheet(isPresented: $showingAddEditSheet) {
            NavigationView {
                 IOSAddEditFoodItemView(foodData: foodData, foodToEdit: foodToEdit)
            }
        }
        .confirmationDialog( /* Dialog oförändrad */
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
