// Kolkalk.zip/kolkalk Watch App/NumpadView.swift
import SwiftUI

// Enum för att definiera Numpadens läge
enum NumpadMode {
    case foodItem // För att mata in gram/dl/st för ett livsmedel
    case numericValue // För att mata in ett generellt numeriskt värde (som Double/String)
}

// Custom button styles (oförändrade)
struct MinimalButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.clear)
            .foregroundColor(.gray)
            .cornerRadius(4)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct CustomButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Color.gray)
            .foregroundColor(.white)
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .shadow(color: .clear, radius: 0)
    }
}

struct CustomNumpadButton: View {
    let label: String
    let width: CGFloat
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.title3)
                .frame(width: width, height: height)
        }
        .buttonStyle(CustomButtonStyle())
    }
}

struct CustomNumpadButtonWithLongPress: View {
    let label: String
    let width: CGFloat
    let height: CGFloat
    let shortPressAction: () -> Void
    let longPressAction: () -> Void
    @State private var isLongPressActive = false

    var body: some View {
        Button(action: {
            if !isLongPressActive { shortPressAction() }
            isLongPressActive = false
        }) {
            Text(label)
                .font(.title3)
                .multilineTextAlignment(.center)
                .frame(width: width, height: height)
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    longPressAction()
                    isLongPressActive = true
                }
        )
        .buttonStyle(CustomButtonStyle())
    }
}

struct NumpadView: View {
    // Använder Binding<String> för generell inmatning
    @Binding var valueString: String
    var title: String // Titel för vyn
    var mode: NumpadMode // Läge för numpaden

    // Parametrar specifika för foodItem-läget (optionella)
    var foodName: String?
    var carbsPer100g: Double?
    var gramsPerDl: Double?
    var styckPerGram: Double?
    // Closure för foodItem-läget (optionell)
    var onConfirmFoodItem: ((Double, String) -> Void)?

    @Environment(\.presentationMode) var presentationMode
    @State private var inputString: String = "0" // Behålls för intern hantering
    @State private var unit: String = "g" // Endast relevant i foodItem-läge
    let maxInputLength = 7

    var body: some View {
        GeometryReader { geometry in
            // <<< CHANGE START >>>
            // Ändrade spacing i huvud-VStack till 4 för lite mer luft mellan fält och knappar
            VStack(spacing: 4) {
            // <<< CHANGE END >>>
                // Dynamiskt inmatningsfält baserat på mode
                Group {
                    if mode == .foodItem {
                        HStack {
                            Text("\(inputString)\(unit)")
                                .font(.system(size: 20))
                                .frame(maxWidth: geometry.size.width * 0.5, alignment: .leading)
                                .foregroundColor(.white)
                                .onTapGesture {
                                    toggleUnit() // Tillåt bara enhetsbyte i foodItem-läge
                                }
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)

                            Spacer()

                            Text("\(calculatedCarbs(), specifier: "%.1f")gk")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .frame(maxWidth: geometry.size.width * 0.5, alignment: .trailing)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                         // Lägg till lite horisontell padding här istället om det behövs
                         .padding(.horizontal, 4)

                    } else { // mode == .numericValue
                        Text(inputString)
                            .font(.system(size: 20))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundColor(.white)
                            .padding(.horizontal) // Behåll horisontell padding för numericValue
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
                // <<< CHANGE START >>>
                // Ta bort .padding(.vertical, 10) härifrån
                // Lägg till en liten padding under fältet om det behövs
                 .padding(.bottom, 4)
                // <<< CHANGE END >>>


                // Numpad-knappar (layout oförändrad)
                // Justera knapparnas höjd något om det fortfarande är trångt
                let buttonWidth = geometry.size.width / 5
                // Prova att minska höjden lite till om det behövs, t.ex. / 10.5 eller / 11
                let buttonHeight = geometry.size.height / 10.5

                VStack(spacing: 4) { // Mellanrum mellan knapprader
                    HStack(spacing: 4) { // Mellanrum mellan knappar i en rad
                        CustomNumpadButton(label: "1", width: buttonWidth, height: buttonHeight, action: { appendNumber("1") })
                        CustomNumpadButton(label: "2", width: buttonWidth, height: buttonHeight, action: { appendNumber("2") })
                        CustomNumpadButton(label: "3", width: buttonWidth, height: buttonHeight, action: { appendNumber("3") })
                    }
                    HStack(spacing: 4) {
                        CustomNumpadButton(label: "4", width: buttonWidth, height: buttonHeight, action: { appendNumber("4") })
                        CustomNumpadButton(label: "5", width: buttonWidth, height: buttonHeight, action: { appendNumber("5") })
                        CustomNumpadButton(label: "6", width: buttonWidth, height: buttonHeight, action: { appendNumber("6") })
                    }
                    HStack(spacing: 4) {
                        CustomNumpadButton(label: "7", width: buttonWidth, height: buttonHeight, action: { appendNumber("7") })
                        CustomNumpadButton(label: "8", width: buttonWidth, height: buttonHeight, action: { appendNumber("8") })
                        CustomNumpadButton(label: "9", width: buttonWidth, height: buttonHeight, action: { appendNumber("9") })
                    }
                    HStack(spacing: 4) {
                        CustomNumpadButton(label: "⌫", width: buttonWidth, height: buttonHeight, action: { backspace() })
                        CustomNumpadButtonWithLongPress(label: "0/,", width: buttonWidth, height: buttonHeight, shortPressAction: { appendNumber("0") }, longPressAction: { appendComma() })
                        CustomNumpadButton(label: "OK", width: buttonWidth, height: buttonHeight, action: { confirm() })
                    }
                }
                // Denna frame gör att knapp-VStacken försöker ta upp resten av utrymmet.
                // Om du vill att knapparna ska ligga tätare mot botten kan du ta bort maxHeight.
                // Men detta bör fungera nu när paddingen ovanför är borta.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.black)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let initialValue = valueString.replacingOccurrences(of: ",", with: ".")
            if !initialValue.isEmpty && Double(initialValue) != nil {
                 inputString = valueString.isEmpty ? "0" : valueString
            } else {
                 inputString = "0"
            }
            if mode == .foodItem, let currentUnit = extractUnit(from: valueString) {
                 unit = currentUnit
                 inputString = valueString.replacingOccurrences(of: currentUnit, with: "")
                 if inputString.isEmpty { inputString = "0" }
            }
             else if valueString == "0" {
                 inputString = "0"
             }
        }
    }

    // MARK: - Funktioner (oförändrade från förra korrigeringen)

    func extractUnit(from string: String) -> String? {
        if string.hasSuffix("dl") { return "dl" }
        if string.hasSuffix("st") { return "st" }
        if string.hasSuffix("g") { return "g" }
        return nil
    }

    func toggleUnit() {
        guard mode == .foodItem else { return }
        if unit == "g" {
            if let grams = gramsPerDl, grams != 0 { unit = "dl" }
            else if let styck = styckPerGram, styck != 0 { unit = "st" }
        } else if unit == "dl" {
            if let styck = styckPerGram, styck != 0 { unit = "st" }
            else { unit = "g" }
        } else {
            unit = "g"
        }
    }

    func calculatedCarbs() -> Double {
        guard mode == .foodItem, let carbs100 = carbsPer100g else { return 0.0 }
        let inputValue = Double(inputString.replacingOccurrences(of: ",", with: ".")) ?? 0
        switch unit {
        case "g":
            return (carbs100 / 100.0) * inputValue
        case "dl":
            guard let gramsDl = gramsPerDl, gramsDl > 0 else { return 0.0 }
            return (carbs100 / 100.0) * gramsDl * inputValue
        case "st":
            guard let styckG = styckPerGram, styckG > 0 else { return 0.0 }
            return (carbs100 / 100.0) * styckG * inputValue
        default:
            print("Warning: Unexpected unit '\(unit)' in calculatedCarbs")
            return (carbs100 / 100.0) * inputValue
        }
    }

    func appendNumber(_ number: String) {
        if inputString.count < maxInputLength {
            if inputString == "0" && number != "," {
                 inputString = number
             } else {
                if inputString == "0" && number == "0" { return }
                inputString += number
            }
        }
    }

    func appendComma() {
        if !inputString.contains(",") && inputString.count < maxInputLength {
            inputString += ","
        }
    }

    func backspace() {
        if !inputString.isEmpty {
            inputString.removeLast()
            if inputString.isEmpty { inputString = "0" }
             else if inputString == "-" { inputString = "0" }
        }
         else if inputString == "0" { return }
    }

    func confirm() {
        let finalInput = inputString
        if mode == .foodItem {
            let sanitizedInput = finalInput.replacingOccurrences(of: ",", with: ".")
            if let doubleValue = Double(sanitizedInput) {
                onConfirmFoodItem?(doubleValue, unit)
            } else {
                print("NumpadView Error: Invalid double value for food item mode.")
            }
        } else { // mode == .numericValue
             if finalInput.isEmpty || finalInput == "-" {
                 valueString = "0"
             } else {
                 valueString = finalInput
             }
        }
        presentationMode.wrappedValue.dismiss()
    }
}
