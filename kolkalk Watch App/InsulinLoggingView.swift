// kolkalk Watch App/InsulinLoggingView.swift

import SwiftUI
import HealthKit

struct InsulinLoggingView: View {
    @State private var shortActingDose: Double = 0
    @State private var longActingDose: Double = 0

    // Variabler för senaste loggade datum
    @State private var lastShortActingLogDate: Date?
    @State private var lastLongActingLogDate: Date?

    // Enum för att hantera vilken alert som ska visas
    enum ActiveAlert: Identifiable, Equatable {
        case shortActingSuccess
        case longActingSuccess
        case error(String)

        var id: String {
            switch self {
            case .shortActingSuccess:
                return "shortActingSuccess"
            case .longActingSuccess:
                return "longActingSuccess"
            case .error(let message):
                return "error-\(message)"
            }
        }
    }

    @State private var activeAlert: ActiveAlert?

    // Ladda senaste värden från UserDefaults
    init() {
        if let savedShortActingDose = UserDefaults.standard.value(forKey: "lastShortActingDose") as? Double {
            _shortActingDose = State(initialValue: savedShortActingDose)
        }
        if let savedLongActingDose = UserDefaults.standard.value(forKey: "lastLongActingDose") as? Double {
            _longActingDose = State(initialValue: savedLongActingDose)
        }
        if let savedShortActingLogDate = UserDefaults.standard.object(forKey: "lastShortActingLogDate") as? Date {
            _lastShortActingLogDate = State(initialValue: savedShortActingLogDate)
        }
        if let savedLongActingLogDate = UserDefaults.standard.object(forKey: "lastLongActingLogDate") as? Date {
            _lastLongActingLogDate = State(initialValue: savedLongActingLogDate)
        }
    }

    var body: some View {
        Form {
            Section(header: VStack(alignment: .leading, spacing: 2) {
                Text("Korttidsverkande insulin")
                if let lastDate = lastShortActingLogDate {
                    Text("Senast loggad: \(lastDate, formatter: dateFormatter)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }) {
                Picker("Korttidsverkande", selection: $shortActingDose) {
                    ForEach(0...100, id: \.self) { value in
                        Text("\(value) enheter").tag(Double(value))
                    }
                }
                .pickerStyle(WheelPickerStyle())

                Button("Logga korttidsverkande") {
                    logInsulin(dose: shortActingDose, type: .shortActing)
                }
                .foregroundColor(.blue)
            }

            Section(header: VStack(alignment: .leading, spacing: 2) {
                Text("Långtidsverkande insulin")
                if let lastDate = lastLongActingLogDate {
                    Text("Senast loggad: \(lastDate, formatter: dateFormatter)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }) {
                Picker("Långtidsverkande", selection: $longActingDose) {
                    ForEach(0...100, id: \.self) { value in
                        Text("\(value) enheter").tag(Double(value))
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
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .shortActingSuccess:
                return Alert(title: Text("Lyckades"), message: Text("Korttidsverkande insulin har loggats."), dismissButton: .default(Text("OK")))
            case .longActingSuccess:
                return Alert(title: Text("Lyckades"), message: Text("Långtidsverkande insulin har loggats."), dismissButton: .default(Text("OK")))
            case .error(let message):
                return Alert(title: Text("Fel"), message: Text(message), dismissButton: .default(Text("OK")))
            }
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
                    // Spara senaste värdet och tidpunkt till UserDefaults
                    let now = Date()
                    switch type {
                    case .shortActing:
                        UserDefaults.standard.set(dose, forKey: "lastShortActingDose")
                        UserDefaults.standard.set(now, forKey: "lastShortActingLogDate")
                        lastShortActingLogDate = now
                        activeAlert = .shortActingSuccess
                    case .longActing:
                        UserDefaults.standard.set(dose, forKey: "lastLongActingDose")
                        UserDefaults.standard.set(now, forKey: "lastLongActingLogDate")
                        lastLongActingLogDate = now
                        activeAlert = .longActingSuccess
                    }
                } else {
                    // Hantera fel
                    let errorMessage = error?.localizedDescription ?? "Okänt fel"
                    activeAlert = .error(errorMessage)
                    print("Fel vid loggning av insulin: \(errorMessage)")
                }
            }
        }
    }

    // DateFormatter för att formatera datum och tid
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
}

