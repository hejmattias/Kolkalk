// kolkalk Watch App/InsulinLoggingView.swift

import SwiftUI
import HealthKit

struct InsulinLoggingView: View {
    @State private var shortActingDose: Double = 0
    @State private var longActingDose: Double = 0

    @State private var showShortActingConfirmation = false
    @State private var showLongActingConfirmation = false

    // Ladda senaste värden från UserDefaults
    init() {
        if let savedShortActingDose = UserDefaults.standard.value(forKey: "lastShortActingDose") as? Double {
            _shortActingDose = State(initialValue: savedShortActingDose)
        }
        if let savedLongActingDose = UserDefaults.standard.value(forKey: "lastLongActingDose") as? Double {
            _longActingDose = State(initialValue: savedLongActingDose)
        }
    }

    var body: some View {
        Form {
            Section(header: Text("Korttidsverkande insulin")) {
                Picker("Korttidsverkande", selection: $shortActingDose) {
                    ForEach(Array(stride(from: 0.0, through: 100.0, by: 0.5)), id: \.self) { value in
                        Text("\(value, specifier: "%.1f") enheter").tag(Double(value))
                    }
                }
                .pickerStyle(WheelPickerStyle())

                Button("Logga korttidsverkande") {
                    logInsulin(dose: shortActingDose, type: .shortActing)
                }
                .foregroundColor(.blue)
            }

            Section(header: Text("Långtidsverkande insulin")) {
                Picker("Långtidsverkande", selection: $longActingDose) {
                    ForEach(Array(stride(from: 0.0, through: 100.0, by: 0.5)), id: \.self) { value in
                        Text("\(value, specifier: "%.1f") enheter").tag(Double(value))
                    }
                }
                .pickerStyle(WheelPickerStyle())

                Button("Logga långtidsverkande") {
                    logInsulin(dose: longActingDose, type: .longActing)
                }
                .foregroundColor(.blue)
            }
        }
        .navigationTitle("Logga insulin")
        .alert(isPresented: $showShortActingConfirmation) {
            Alert(title: Text("Lyckades"), message: Text("Korttidsverkande insulin har loggats."), dismissButton: .default(Text("OK")))
        }
        .alert(isPresented: $showLongActingConfirmation) {
            Alert(title: Text("Lyckades"), message: Text("Långtidsverkande insulin har loggats."), dismissButton: .default(Text("OK")))
        }
    }

    enum InsulinType {
        case shortActing
        case longActing
    }

    private func logInsulin(dose: Double, type: InsulinType) {
        guard dose > 0 else { return }

        let insulinDeliveryReason: HKInsulinDeliveryReason = (type == .shortActing) ? .bolus : .basal

        HealthKitManager.shared.logInsulinDose(dose: dose, insulinType: insulinDeliveryReason) { success, error in
            DispatchQueue.main.async {
                if success {
                    // Spara senaste värdet till UserDefaults
                    switch type {
                    case .shortActing:
                        UserDefaults.standard.set(dose, forKey: "lastShortActingDose")
                        showShortActingConfirmation = true
                    case .longActing:
                        UserDefaults.standard.set(dose, forKey: "lastLongActingDose")
                        showLongActingConfirmation = true
                    }
                } else {
                    // Hantera fel
                    print("Fel vid loggning av insulin: \(error?.localizedDescription ?? "Okänt fel")")
                }
            }
        }
    }
}
