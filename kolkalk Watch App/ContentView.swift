import SwiftUI

// MARK: - Global Route Enum
enum Route: Hashable {
    case plateView
    case foodListView(isEmptyAndAdd: Bool)
    case createFoodFromPlateView
    case foodDetailView(FoodItem, shouldEmptyPlate: Bool)
    case createNewFoodItem
    case editFoodItem(FoodItem)
    case importInstructions
}

struct ContentView: View {
    @ObservedObject var plate = Plate.shared
    @ObservedObject var foodData = WatchViewModel.shared.foodData
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

                NavigationLink(value: Route.importInstructions) {
                    Text("Importera livsmedel från CSV")
                }

                // Knapp för att exportera livsmedelslistan
                Button(action: {
                    WatchViewModel.shared.exportFoodList()
                }) {
                    Text("Exportera livsmedelslista")
                        .foregroundColor(.blue)
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
                case .importInstructions:
                    ImportInstructionsView()
                }
            }
            .navigationTitle("Totalt: \(totalCarbs, specifier: "%.1f") gk")
            .onOpenURL { url in
                handleDeepLink(url: url)
            }
        }
    }

    // MARK: - Handle Deep Link
    func handleDeepLink(url: URL) {
        switch url.host {
        case "addFood":
            navigationPath = NavigationPath([Route.foodListView(isEmptyAndAdd: false)])
        case "emptyAndAddFood":
            navigationPath = NavigationPath([Route.foodListView(isEmptyAndAdd: true)])
        case "FoodPlate":
            navigationPath = NavigationPath([Route.plateView])
        default:
            break
        }
    }
}
