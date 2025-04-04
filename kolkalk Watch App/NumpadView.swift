// Kolkalk.zip/kolkalk Watch App/NumpadView.swift
import SwiftUI

// Enum (oförändrad)
enum NumpadMode {
    case foodItem
    case numericValue
}

// Knappvy (oförändrad)
struct NumpadStyledButton: View {
    let label: String
    let width: CGFloat
    let height: CGFloat
    let fontSize: CGFloat
    var backgroundColor: Color = Color(white: 0.3)
    var foregroundColor: Color = .white
    var isHighlighted: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: fontSize))
                .frame(width: width, height: height)
                .foregroundColor(isDisabled ? .gray : (isHighlighted ? .black : foregroundColor))
                .background(isDisabled ? Color(white: 0.2) : (isHighlighted ? .orange : backgroundColor))
                .cornerRadius(5)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}


struct NumpadView: View {
    // Binding etc. (oförändrade)
    @Binding var valueString: String
    var title: String
    var mode: NumpadMode
    var foodName: String?
    var carbsPer100g: Double?
    var gramsPerDl: Double?
    var styckPerGram: Double?
    var onConfirmFoodItem: ((Double, String) -> Void)?

    @Environment(\.presentationMode) var presentationMode
    @State private var inputString: String = "0"
    @State private var unit: String = "g"
    let maxInputLength = 7

    // Färger (oförändrade)
    let unitButtonColor = Color.orange
    let unitButtonHighlightedColor = Color.orange.opacity(0.6)
    let disabledUnitButtonColor = Color(white: 0.2)
    let defaultButtonColor = Color(white: 0.3)
    let backspaceButtonColor = Color(white: 0.4)
    let okButtonColor = Color.blue

    func isUnitAvailable(_ targetUnit: String) -> Bool {
        guard mode == .foodItem else { return false }
        switch targetUnit {
        case "g": return true
        case "dl": return gramsPerDl != nil && gramsPerDl! > 0
        case "st": return styckPerGram != nil && styckPerGram! > 0
        default: return false
        }
    }

    var body: some View {
        GeometryReader { geometry in
            // Exakta kopieringar av konstanter och beräkningar från CalculatorView
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            let spacing: CGFloat = 1
            let columns: CGFloat = 4
            let rows: CGFloat = 4
            let totalSpacingWidth = spacing * (columns + 1)
            let totalSpacingHeight = spacing * (rows + 1)

            // <<< CHANGE START >>>
            // Återgå till exakt samma beräkning som CalculatorView
            let inputFontSize = screenHeight * 0.1
            // <<< CHANGE END >>>
            let inputFieldHeight = screenHeight * 0.1 // Använd FIXED height

            let availableWidth = screenWidth - totalSpacingWidth
            let availableHeight = screenHeight - totalSpacingHeight
            let buttonWidth = availableWidth / columns
            let buttonHeight = availableHeight / rows

            let buttonFontSize = buttonHeight * 0.4


             VStack(spacing: spacing) { // Använd exakt spacing

                // Inmatningsfält
                Group {
                    if mode == .foodItem {
                        HStack(spacing: 0) {
                            Text("\(inputString)\(unit)")
                                .font(.system(size: inputFontSize))
                                .lineLimit(1)
                                //.minimumScaleFactor(0.5) // <<< BORTTAGEN FÖR ATT MATCHA CALC VIEW
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Spacer()
                            Text("\(calculatedCarbs(), specifier: "%.1f")gk")
                                .font(.system(size: inputFontSize))
                                .lineLimit(1)
                                //.minimumScaleFactor(0.5) // <<< BORTTAGEN FÖR ATT MATCHA CALC VIEW
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(.horizontal, 5)
                    } else { // mode == .numericValue
                        Text(inputString)
                            .font(.system(size: inputFontSize))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            //.minimumScaleFactor(0.5) // <<< BORTTAGEN FÖR ATT MATCHA CALC VIEW
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.horizontal, 5)
                    }
                }
                 .frame(height: inputFieldHeight) // Använd FIXERAD höjd
                 .padding(.bottom, spacing)


                 // Knapparna (oförändrade från förra gången)
                 VStack(spacing: spacing) {
                      // Rad 1: 7, 8, 9, g
                     HStack(spacing: spacing) {
                         NumpadStyledButton(label: "7", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: defaultButtonColor, action: { appendNumber("7") })
                         NumpadStyledButton(label: "8", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: defaultButtonColor, action: { appendNumber("8") })
                         NumpadStyledButton(label: "9", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: defaultButtonColor, action: { appendNumber("9") })
                         NumpadStyledButton(label: "g", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize,
                                            backgroundColor: unitButtonColor,
                                            isHighlighted: unit == "g" && mode == .foodItem,
                                            isDisabled: mode != .foodItem,
                                            action: { setUnit("g") })
                     }
                      // Rad 2: 4, 5, 6, dl
                     HStack(spacing: spacing) {
                         NumpadStyledButton(label: "4", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: defaultButtonColor, action: { appendNumber("4") })
                         NumpadStyledButton(label: "5", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: defaultButtonColor, action: { appendNumber("5") })
                         NumpadStyledButton(label: "6", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: defaultButtonColor, action: { appendNumber("6") })
                         NumpadStyledButton(label: "dl", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize,
                                            backgroundColor: unitButtonColor,
                                            isHighlighted: unit == "dl" && mode == .foodItem,
                                            isDisabled: !isUnitAvailable("dl"),
                                            action: { setUnit("dl") })
                     }
                     // Rad 3: 1, 2, 3, st
                     HStack(spacing: spacing) {
                         NumpadStyledButton(label: "1", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: defaultButtonColor, action: { appendNumber("1") })
                         NumpadStyledButton(label: "2", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: defaultButtonColor, action: { appendNumber("2") })
                         NumpadStyledButton(label: "3", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: defaultButtonColor, action: { appendNumber("3") })
                         NumpadStyledButton(label: "st", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize,
                                            backgroundColor: unitButtonColor,
                                            isHighlighted: unit == "st" && mode == .foodItem,
                                            isDisabled: !isUnitAvailable("st"),
                                            action: { setUnit("st") })
                     }
                      // Rad 4: ,, 0, ⌫, OK
                     HStack(spacing: spacing) {
                         NumpadStyledButton(label: ",", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: defaultButtonColor, action: { appendComma() })
                         NumpadStyledButton(label: "0", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: defaultButtonColor, action: { appendNumber("0") })
                         NumpadStyledButton(label: "⌫", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: backspaceButtonColor, action: { backspace() })
                         NumpadStyledButton(label: "OK", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: okButtonColor, action: { confirm() })
                     }
                 }
            }
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
             // Initieringslogik (oförändrad)
            if mode == .foodItem { unit = "g" }
            let initialValue = valueString.replacingOccurrences(of: ",", with: ".")
            if !initialValue.isEmpty && Double(initialValue) != nil {
                 inputString = valueString.isEmpty ? "0" : valueString
            } else {
                 inputString = "0"
            }
             if valueString == "0" {
                 inputString = "0"
             }
        }
    }

    // MARK: - Funktioner (oförändrade)
    // ... (setUnit, calculatedCarbs, appendNumber, appendComma, backspace, confirm) ...
    func setUnit(_ newUnit: String) {
        guard mode == .foodItem && isUnitAvailable(newUnit) else { return }
        unit = newUnit
    }

    func calculatedCarbs() -> Double {
        guard mode == .foodItem, let carbs100 = carbsPer100g else { return 0.0 }
        let inputValue = Double(inputString.replacingOccurrences(of: ",", with: ".")) ?? 0
        switch unit {
        case "g": return (carbs100 / 100.0) * inputValue
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
            if inputString == "0" && number != "," { inputString = number }
            else {
                if inputString == "0" && number == "0" { return }
                inputString += number
            }
        }
    }

    func appendComma() {
        if !inputString.contains(",") && inputString.count < maxInputLength {
             if inputString == "0" { inputString = "0," }
             else { inputString += "," }
        }
    }

    func backspace() {
        if !inputString.isEmpty {
            inputString.removeLast()
            if inputString.isEmpty { inputString = "0" }
             else if inputString == "-" { inputString = "0" }
             else if inputString == "0," && !inputString.contains(".") { inputString = "0" }
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
             if finalInput.isEmpty || finalInput == "-" || finalInput == "," || finalInput == "0," {
                 valueString = "0"
             } else {
                 valueString = finalInput.last == "," ? String(finalInput.dropLast()) : finalInput
             }
        }
        presentationMode.wrappedValue.dismiss()
    }
}
