// Kolkalk.zip/kolkalk Watch App/ContentView.swift
// ContentView.swift

import SwiftUI

// MARK: - Global Route Enum
enum Route: Hashable {
    case plateView
    case foodListView(isEmptyAndAdd: Bool)
    case createFoodFromPlateView
    case foodDetailView(FoodItem, shouldEmptyPlate: Bool)
    case createNewFoodItem
    case editFoodItem(FoodItem)
    case editPlateItem(FoodItem)
    case importInstructions
    case insulinLoggingView
    case calculator(shouldEmptyPlate: Bool)
    case settings // *** NY ROUTE ***
}

struct ContentView: View {
    @ObservedObject var plate = Plate.shared
    @ObservedObject var foodData = WatchViewModel.shared.foodData
    @State private var navigationPath = NavigationPath()

    // *** NYTT: Läs in inställningen för insulinloggning ***
    @AppStorage("enableInsulinLogging") private var enableInsulinLogging = true

    var totalCarbs: Double {
        plate.items.reduce(0) { $0 + $1.totalCarbs }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                NavigationLink(value: Route.plateView) {
                    Label("Visa tallriken", systemImage: "fork.knife.circle") // Lägg till ikon
                }

                NavigationLink(value: Route.foodListView(isEmptyAndAdd: false)) {
                    Label("Lägg till på tallriken", systemImage: "plus.circle") // Lägg till ikon
                }

                NavigationLink(value: Route.foodListView(isEmptyAndAdd: true)) {
                    Label("Töm och lägg till", systemImage: "trash.circle") // Lägg till ikon
                }

                NavigationLink(value: Route.createFoodFromPlateView) {
                    Label("Tallrik till livsmedel", systemImage: "scalemass") // Lägg till ikon
                }

                // *** NYTT: Dölj insulinlänken baserat på inställning ***
                if enableInsulinLogging {
                    NavigationLink(value: Route.insulinLoggingView) {
                        Label("Logga insulin", systemImage: "syringe") // Byt text och lägg till ikon
                    }
                }

                // *** NYTT: Länk till inställningar ***
                NavigationLink(value: Route.settings) {
                     Label("Inställningar", systemImage: "gearshape") // Lägg till ikon
                }
            }
            .onAppear {
                plate.loadFromUserDefaults()
                foodData.loadFromUserDefaults()
                // Begär HealthKit-auktorisation vid start om funktionerna är aktiverade
                 requestAuthIfEnabled()
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
                case .editPlateItem(let item):
                    if item.isCalculatorItem {
                        CalculatorView(plate: plate, navigationPath: $navigationPath, initialCalculation: item.name, itemToEdit: item)
                    } else {
                        EditFoodView(plate: plate, item: item)
                    }
                case .importInstructions:
                    ImportInstructionsView()
                case .insulinLoggingView:
                    InsulinLoggingView()
                case .calculator(let shouldEmptyPlate):
                    CalculatorView(plate: plate, navigationPath: $navigationPath, shouldEmptyPlate: shouldEmptyPlate)
                // *** NYTT: Lägg till destination för settings ***
                case .settings:
                    SettingsView()
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

    // *** NYTT: Funktion för att begära auktorisering vid start ***
    private func requestAuthIfEnabled() {
         // Läs in den andra inställningen här också för att kolla båda
         let enableCarbLogging = UserDefaults.standard.bool(forKey: "enableCarbLogging")
         // Standardvärdet om nyckeln inte finns är false, men vi vill ha true som standard.
         // Om nyckeln *aldrig* har satts (första gången), använd true.
         let carbLoggingSettingExists = UserDefaults.standard.object(forKey: "enableCarbLogging") != nil
         let shouldRequestCarb = carbLoggingSettingExists ? enableCarbLogging : true

         let insulinLoggingSettingExists = UserDefaults.standard.object(forKey: "enableInsulinLogging") != nil
         let shouldRequestInsulin = insulinLoggingSettingExists ? enableInsulinLogging : true


         if shouldRequestCarb || shouldRequestInsulin {
             HealthKitManager.shared.requestAuthorization { success, error in
                 if !success {
                     print("HealthKit authorization was not granted on app start.")
                 }
             }
         }
     }
}
