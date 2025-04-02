// Kolkalk.zip/kolkalk Watch App/ContentView.swift
// ContentView.swift

import SwiftUI

// MARK: - Global Route Enum (Oförändrad)
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
    case settings
}

struct ContentView: View {
    // StateObjects och ObservedObjects
    @ObservedObject var plate = Plate.shared
    @StateObject var foodData = FoodData()
    @State private var navigationPath = NavigationPath()

    @AppStorage("enableInsulinLogging") private var enableInsulinLogging = true

    // Beräkning av totalCarbs
    var totalCarbs: Double {
        plate.items.reduce(0) { $0 + $1.totalCarbs }
    }

    var body: some View {
        // Använder NavigationStack
        NavigationStack(path: $navigationPath) {
            // Rotvyn är en lista med länkar
            List {
                // ***** FÖRSTA LÄNKEN MODIFIERAD (Specifik färg) *****
                NavigationLink(value: Route.plateView) {
                    HStack {
                        Image(systemName: "fork.knife.circle")
                            // *** Sätt rendering mode och specifik färg ***
                            .renderingMode(.template) // Behandla som en mall
                            .foregroundColor(.white) // Sätt färgen till vit

                        VStack(alignment: .leading) {
                            Text("Visa tallriken")
                            Text("Totalt: \(totalCarbs, specifier: "%.1f") gk")
                                .font(.caption)
                                .foregroundColor(.secondary) // Behåll denna för lilla texten
                        }
                        Spacer()
                    }
                } // Slut på modifierad NavigationLink

                // Övriga länkar (Oförändrade - använder standard Label)
                NavigationLink(value: Route.foodListView(isEmptyAndAdd: false)) {
                    Label("Lägg till på tallriken", systemImage: "plus.circle")
                }
                NavigationLink(value: Route.foodListView(isEmptyAndAdd: true)) {
                    Label("Töm och lägg till", systemImage: "trash.circle")
                }
                NavigationLink(value: Route.createFoodFromPlateView) {
                    Label("Tallrik till livsmedel", systemImage: "scalemass")
                }
                if enableInsulinLogging {
                    NavigationLink(value: Route.insulinLoggingView) {
                        Label("Logga insulin", systemImage: "syringe")
                    }
                }
                NavigationLink(value: Route.settings) {
                     Label("Inställningar", systemImage: "gearshape")
                }
            } // Slut List
            .onAppear { // onAppear
                 plate.loadFromUserDefaults()
                 requestAuthIfEnabled()
            }
            .navigationDestination(for: Route.self) { route in // NavigationDestination
                // Switch-satsen som skapar destinationerna är oförändrad...
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
                case .settings:
                    SettingsView()
                }
            }
            .onOpenURL { url in // onOpenURL
                handleDeepLink(url: url)
            }
        } // Slut NavigationStack
    }

    // handleDeepLink (Oförändrad)
    func handleDeepLink(url: URL) {
        switch url.host {
        case "addFood":
            navigationPath = NavigationPath([Route.foodListView(isEmptyAndAdd: false)])
        case "emptyAndAddFood":
            navigationPath = NavigationPath([Route.foodListView(isEmptyAndAdd: true)])
        case "FoodPlate":
            navigationPath = NavigationPath([Route.plateView])
        default:
            navigationPath = NavigationPath()
            break
        }
    }

    // requestAuthIfEnabled (Oförändrad)
    private func requestAuthIfEnabled() {
        let enableCarbLogging = UserDefaults.standard.bool(forKey: "enableCarbLogging")
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
