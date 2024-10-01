import SwiftUI

// Enum for navigeringsvägar
enum Route: Hashable {
    case plateView
    case foodListView(isEmptyAndAdd: Bool)
    case createFoodFromPlateView
    case foodDetailView(FoodItem, shouldEmptyPlate: Bool)
    case createNewFoodItem
    case editFoodItem(FoodItem)  // Redigera livsmedel
}

// Huvudvyn som startar appen
struct ContentView: View {
    @StateObject private var plate = Plate()
    @StateObject private var foodData = FoodData()
    @State private var navigationPath = NavigationPath()

    var totalCarbs: Double {
        plate.items.reduce(0) { $0 + $1.totalCarbs }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                NavigationLink(value: Route.plateView) {
                    Text("Visa tallriken")
                }

                NavigationLink(value: Route.foodListView(isEmptyAndAdd: false)) {
                    Text("Lägg till på tallriken")
                }

                NavigationLink(value: Route.foodListView(isEmptyAndAdd: true)) {
                    Text("Töm och lägg till på tallriken")
                }

                NavigationLink(value: Route.createFoodFromPlateView) {
                    Text("Tallrik till livsmedel")
                }
            }
            .onAppear {
                plate.loadFromUserDefaults()
                foodData.loadFromUserDefaults()
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .plateView:
                    PlateView(plate: plate, navigationPath: $navigationPath)
                case .foodListView(let isEmptyAndAdd):
                    FoodListView(plate: plate, foodData: foodData, navigationPath: $navigationPath, isEmptyAndAdd: isEmptyAndAdd)
                case .createFoodFromPlateView:
                    CreateFoodFromPlateView(plate: plate, foodData: foodData, navigationPath: $navigationPath)
                case .foodDetailView(let food, let shouldEmptyPlate):
                    FoodDetailView(plate: plate, food: food, navigationPath: $navigationPath, shouldEmptyPlate: shouldEmptyPlate)
                case .createNewFoodItem:
                    CreateNewFoodItemView(foodData: foodData, navigationPath: $navigationPath)
                case .editFoodItem(let food):
                    EditFoodItemView(food: food, foodData: foodData, navigationPath: $navigationPath)
                }
            }
            .navigationTitle("Totalt: \(totalCarbs, specifier: "%.1f") gk")
        }
    }
}
