// Kolkalk/IOSFoodListView.swift

import SwiftUI

struct IOSFoodListView: View {
    // FoodData skapas nu i ContentView och skickas hit
    @ObservedObject var foodData: FoodData_iOS // Ändra från @StateObject om den skickas in
    @State private var showingAddEditSheet = false
    @State private var foodToEdit: FoodItem? = nil
    @State private var searchText: String = ""
    @State private var showFavoritesOnly: Bool = UserDefaults.standard.bool(forKey: "showFavoritesOnly_iOS")
    @State private var showingDeleteConfirmation = false

    var filteredFoodList: [FoodItem] {
        // Filtrering är oförändrad
        var list = foodData.foodList
        if showFavoritesOnly { list = list.filter { $0.isFavorite } }
        if !searchText.isEmpty { list = list.filter { $0.name.lowercased().contains(searchText.lowercased()) } }
        // Sortering sker nu i FoodData
        return list
    }

    var body: some View {
        // *** Använd ZStack eller Group för att visa laddningsindikator över listan ***
        ZStack {
            // Visa listan normalt
            List {
                 Toggle("Visa endast favoriter", isOn: $showFavoritesOnly)
                     .onChange(of: showFavoritesOnly) { newValue in // Använd nya syntaxen om iOS 14+
                         UserDefaults.standard.set(newValue, forKey: "showFavoritesOnly_iOS")
                     }

                ForEach(filteredFoodList) { food in
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
                // Knapp för att radera alla
                 if !foodData.foodList.isEmpty {
                      Button("Radera alla livsmedel", role: .destructive) { showingDeleteConfirmation = true }
                 }
            } // Slut på List

            // *** Visa ProgressView om listan är tom OCH data laddas från CloudKit ***
             if foodData.isLoading && foodData.foodList.isEmpty {
                 ProgressView()
                     .scaleEffect(1.5) // Gör den lite större
                     .progressViewStyle(CircularProgressViewStyle())
                     .frame(maxWidth: .infinity, maxHeight: .infinity) // Centrera
                     .background(Color(UIColor.systemBackground).opacity(0.6)) // Lätt bakgrund för synlighet
             }

        } // Slut på ZStack
        .searchable(text: $searchText, prompt: "Sök livsmedel")
        .navigationTitle("Livsmedel")
        .toolbar { /* Toolbar oförändrad */
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { foodToEdit = nil; showingAddEditSheet = true } label: { Image(systemName: "plus") }
            }
            ToolbarItem(placement: .navigationBarLeading) { EditButton() }
        }
        .sheet(isPresented: $showingAddEditSheet) {
            NavigationView { // Behåll NavigationView i sheet
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
        // .onAppear behövs inte här för att ladda, FoodData sköter det i init
    }
}
