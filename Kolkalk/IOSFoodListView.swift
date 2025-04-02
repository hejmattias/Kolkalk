//
//  IOSFoodListView.swift
//  Kolkalk
//
//  Created by Mattias Göransson on 2025-04-01.
//


// Kolkalk/IOSFoodListView.swift

import SwiftUI

struct IOSFoodListView: View {
    @StateObject var foodData = FoodData_iOS() // Skapa och äg instansen här
    @State private var showingAddEditSheet = false
    @State private var foodToEdit: FoodItem? = nil
    @State private var searchText: String = ""
    @State private var showFavoritesOnly: Bool = UserDefaults.standard.bool(forKey: "showFavoritesOnly_iOS") // Separat nyckel för iOS
    @State private var showingDeleteConfirmation = false

    var filteredFoodList: [FoodItem] {
        var list = foodData.foodList

        if showFavoritesOnly {
            list = list.filter { $0.isFavorite }
        }

        if !searchText.isEmpty {
            list = list.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }

        // Returnera redan sorterad lista om CloudKit-queryn sorterar, annars sortera här
         // list.sort { $0.name.lowercased() < $1.name.lowercased() }
        return list
    }

    var body: some View {
        List {
             Toggle("Visa endast favoriter", isOn: $showFavoritesOnly)
                 .onChange(of: showFavoritesOnly) { newValue in
                     UserDefaults.standard.set(newValue, forKey: "showFavoritesOnly_iOS")
                 }

            ForEach(filteredFoodList) { food in
                HStack {
                    VStack(alignment: .leading) {
                        Text(food.name)
                            .font(.headline)
                        Text("\(food.carbsPer100g ?? 0, specifier: "%.1f") gk / 100g")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    if food.isFavorite {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                    }
                }
                .contentShape(Rectangle()) // Gör hela raden klickbar
                .onTapGesture {
                    foodToEdit = food
                    showingAddEditSheet = true
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        foodData.deleteFoodItem(withId: food.id)
                    } label: {
                        Label("Ta bort", systemImage: "trash")
                    }
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
            }

            // Knapp för att radera alla
            if !foodData.foodList.isEmpty {
                 Button("Radera alla livsmedel", role: .destructive) {
                     showingDeleteConfirmation = true
                 }
            }

        }
        .searchable(text: $searchText, prompt: "Sök livsmedel") // Lägg till sökfält
        .navigationTitle("Livsmedel")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    foodToEdit = nil // Säkerställ att vi skapar nytt
                    showingAddEditSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                 EditButton() // Standard redigera/klar-knapp (fungerar med onDelete)
            }
        }
        .sheet(isPresented: $showingAddEditSheet) {
            // Återanvänd samma vy för add/edit
            NavigationView { // Lägg till NavigationView för titel och knappar i sheet
                 IOSAddEditFoodItemView(foodData: foodData, foodToEdit: foodToEdit)
            }
        }
        .confirmationDialog(
             "Radera Alla",
             isPresented: $showingDeleteConfirmation,
             titleVisibility: .visible
         ) {
             Button("Radera alla livsmedel", role: .destructive) {
                 foodData.deleteAllFoodItems()
             }
             Button("Avbryt", role: .cancel) {}
         } message: {
             Text("Är du säker på att du vill radera alla livsmedel? Detta kan inte ångras och påverkar alla dina enheter.")
         }
        // .onAppear {
        //     foodData.loadFoodList() // Ladda listan när vyn visas (kan behövas om den inte uppdateras via prenumeration)
        // }
    }
}