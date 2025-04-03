// Kolkalk/IOSFoodListView.swift

import SwiftUI

// FoodItemRowView (oförändrad från förra svaret, tar emot toggleAction)
struct FoodItemRowView: View {
    let food: FoodItem
    var toggleAction: () -> Void // Tar emot en funktion för att växla favorit
    @Binding var foodToEdit: FoodItem?
    @Binding var showingAddEditSheet: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(food.name).font(.headline)
                Text("\(food.carbsPer100g ?? 0, specifier: "%.1f") gk / 100g").font(.caption).foregroundColor(.gray)
            }
            Spacer()
            Button {
                // Anropar den mottagna toggleAction-funktionen
                toggleAction()
            } label: {
                Image(systemName: food.isFavorite ? "heart.fill" : "heart")
                    .foregroundColor(food.isFavorite ? .red : .gray)
                    .imageScale(.large)
                    .padding(.leading, 5)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            foodToEdit = food
            showingAddEditSheet = true
        }
        // Swipe actions måste hanteras i ForEach där foodData finns tillgängligt.
    }
}


struct IOSFoodListView: View {
    @StateObject var foodData: FoodData_iOS
    @State private var showingAddEditSheet = false
    @State private var foodToEdit: FoodItem? = nil
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
        if showFavoritesOnly { list = list.filter { $0.isFavorite } }
        if !searchText.isEmpty { list = list.filter { $0.name.lowercased().contains(searchText.lowercased()) } }
        return list
    }

    var body: some View {
        ZStack {
            List {
                Toggle("Visa endast favoriter", isOn: $showFavoritesOnly)
                    // *** Uppdaterad onChange-syntax ***
                     .onChange(of: showFavoritesOnly) {
                         UserDefaults.standard.set(showFavoritesOnly, forKey: "showFavoritesOnly_iOS")
                     }
                    // *** SLUT ÄNDRING ***

                ForEach(filteredFoodList) { food in
                    // *** ÄNDRING: Innehållet i toggleAction-closuren ***
                    FoodItemRowView(
                        food: food,
                        // Denna closure körs när hjärtat i FoodItemRowView trycks
                        toggleAction: {
                            // 1. Skapa en muterbar kopia av food-objektet
                            var updatedFood = food
                            // 2. Växla isFavorite-värdet på kopian
                            updatedFood.isFavorite.toggle()
                            // 3. Anropa den befintliga updateFoodItem-funktionen med den ändrade kopian
                            foodData.updateFoodItem(updatedFood)
                            print("Anropade updateFoodItem för \(updatedFood.name) med isFavorite=\(updatedFood.isFavorite)") // För felsökning
                        },
                        foodToEdit: $foodToEdit,
                        showingAddEditSheet: $showingAddEditSheet
                    )
                    // Swipe actions flyttade hit där foodData finns
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { foodData.deleteFoodItem(withId: food.id) } label: { Label("Ta bort", systemImage: "trash") }
                    }
                    .swipeActions(edge: .leading) {
                         Button {
                             foodToEdit = food
                             showingAddEditSheet = true
                         } label: {
                             Label("Redigera", systemImage: "pencil")
                         }
                         .tint(.blue)
                     }
                     // *** SLUT ÄNDRING ***
                }

                if !foodData.foodList.isEmpty {
                     Button("Radera alla livsmedel", role: .destructive) { showingDeleteConfirmation = true }
                }

                // Statussektion (oförändrad)
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

            // Laddningsindikator (oförändrad)
            if foodData.isLoading && foodData.foodList.isEmpty {
                ProgressView("Laddar livsmedel...")
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
