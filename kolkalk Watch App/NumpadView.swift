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

    let underlineColor: Color = .white
    let underlineHeight: CGFloat = 2

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: fontSize))
                    .foregroundColor(isDisabled ? .gray : foregroundColor)

                if isHighlighted && !isDisabled {
                    Rectangle()
                        .frame(height: underlineHeight)
                        .foregroundColor(underlineColor)
                        .padding(.horizontal, width * 0.1)
                } else {
                     Rectangle().fill(Color.clear).frame(height: underlineHeight)
                 }
            }
            .frame(width: width, height: height)
            .background(isDisabled ? Color(white: 0.2) : backgroundColor)
            .cornerRadius(5)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}


struct NumpadView: View {
    // Binding etc.
    @Binding var valueString: String
    var title: String
    var mode: NumpadMode
    var foodName: String?
    var carbsPer100g: Double?
    var gramsPerDl: Double?
    var styckPerGram: Double?
    var initialUnit: String?
    var onConfirmFoodItem: ((Double, String) -> Void)?
    // Parameter för att signalera navigering efter dismiss
    var onDismissAndNavigate: (() -> Void)? = nil

    @Environment(\.presentationMode) var presentationMode
    @State private var inputString: String = "0"
    @State private var unit: String = "g"
    let maxInputLength = 7

    // Färger (oförändrade)
    let unitButtonColor = Color.orange
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
            // Layoutberäkningar (oförändrade)
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            let spacing: CGFloat = 1
            let columns: CGFloat = 4
            let rows: CGFloat = 4
            let totalSpacingWidth = spacing * (columns + 1)
            let totalSpacingHeight = spacing * (rows + 1)
            let inputFontSize = screenHeight * 0.1
            let inputFieldHeight = screenHeight * 0.1
            let availableWidth = screenWidth - totalSpacingWidth
            let availableHeight = screenHeight - totalSpacingHeight
            let buttonWidth = availableWidth / columns
            let buttonHeight = availableHeight / rows
            let buttonFontSize = buttonHeight * 0.4

             VStack(spacing: spacing) {

                // Inmatningsfält (oförändrat)
                Group {
                    if mode == .foodItem {
                        HStack(spacing: 0) {
                            Text("\(inputString)\(unit)")
                                .font(.system(size: inputFontSize))
                                .lineLimit(1)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Spacer()
                            Text("\(calculatedCarbs(), specifier: "%.1f")gk")
                                .font(.system(size: inputFontSize))
                                .lineLimit(1)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(.horizontal, 5)
                    } else {
                        Text(inputString)
                            .font(.system(size: inputFontSize))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.horizontal, 5)
                    }
                }
                 .frame(height: inputFieldHeight)
                 .padding(.bottom, spacing)


                 // Knapparna (oförändrade)
                 VStack(spacing: spacing) {
                     HStack(spacing: spacing) {
                         NumpadStyledButton(label: "7", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: defaultButtonColor, action: { appendNumber("7") })
                         NumpadStyledButton(label: "8", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: defaultButtonColor, action: { appendNumber("8") })
                         NumpadStyledButton(label: "9", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: defaultButtonColor, action: { appendNumber("9") })
                         NumpadStyledButton(label: "g", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize,
                                            backgroundColor: unitButtonColor,
                                            isHighlighted: unit == "g" && mode == .foodItem,
                                            isDisabled: false,
                                            action: { setUnit("g") })
                     }
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
                     HStack(spacing: spacing) {
                         NumpadStyledButton(label: ",", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: defaultButtonColor, action: { appendComma() })
                         NumpadStyledButton(label: "0", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: defaultButtonColor, action: { appendNumber("0") })
                         NumpadStyledButton(label: "⌫", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: backspaceButtonColor, action: { backspace() })
                         NumpadStyledButton(label: "OK", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: okButtonColor, action: { confirm() }) // Anropar confirm()
                     }
                 }
            }
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Sätt initial enhet (oförändrat)
            if mode == .foodItem {
                if let initUnit = initialUnit, isUnitAvailable(initUnit) {
                    unit = initUnit
                } else {
                    unit = "g"
                }
            }
            // --- ÄNDRING: Nollställningslogik och formatering av inputString ---
            if valueString.isEmpty {
                inputString = "0"
            } else {
                // Konvertera till Double för att korrekt hantera "0,0", "0,00" etc. som "0"
                let numericTest = Double(valueString.replacingOccurrences(of: ",", with: "."))
                if let num = numericTest, num == 0.0 {
                    inputString = "0"
                } else {
                    // Använd formatForInitialDisplay för att ta bort onödiga .00
                    inputString = valueString.formatForInitialDisplay()
                }
            }
            // --- SLUT ÄNDRING ---
        }
    }

    // MARK: - Funktioner (oförändrade utom confirm)
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
        default: return (carbs100 / 100.0) * inputValue
        }
    }

    func appendNumber(_ number: String) {
        guard inputString.count < maxInputLength || inputString == "0" else { return }
        if inputString == "0" {
             if number == "," { inputString = "0," }
             else { inputString = number }
        } else {
            if number == "," {
                 if !inputString.contains(",") { inputString += number }
             } else { inputString += number }
        }
        if inputString.count > maxInputLength {
             inputString = String(inputString.prefix(maxInputLength))
        }
    }

    func appendComma() { appendNumber(",") }

    func backspace() {
        if !inputString.isEmpty {
            inputString.removeLast()
            if inputString.isEmpty { inputString = "0" }
        }
    }

    // Modifierad confirm()
    func confirm() {
        let finalInput = inputString
        let shouldNavigate = mode == .foodItem // Vi vill bara navigera efter att ha lagt till mat

        if mode == .foodItem {
            let sanitizedInput = finalInput.replacingOccurrences(of: ",", with: ".")
            if let doubleValue = Double(sanitizedInput) {
                onConfirmFoodItem?(doubleValue, unit) // Anropa befintlig closure för att uppdatera plate
            } else {
                onConfirmFoodItem?(0.0, unit)
            }
        } else {
             var cleanedInput = finalInput.last == "," ? String(finalInput.dropLast()) : finalInput
             if cleanedInput.isEmpty || cleanedInput == "-" { cleanedInput = "0" }
             // --- ÄNDRING: Använd formatForInitialDisplay även här för slutvärdet ---
             valueString = cleanedInput.formatForInitialDisplay()
             // --- SLUT ÄNDRING ---
        }

        // Stäng sheeten FÖRST
        presentationMode.wrappedValue.dismiss()

        // Om vi ska navigera, anropa den nya closuren EFTER dismiss
        if shouldNavigate {
            // Använd en kort asynkron fördröjning för att låta sheet-animationen slutföras
            // innan navigeringsclosuren körs. Detta kan hjälpa NavigationStack.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                 onDismissAndNavigate?()
            }
        }
    }
}
