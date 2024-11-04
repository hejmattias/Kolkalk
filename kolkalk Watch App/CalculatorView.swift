import SwiftUI

struct CalculatorView: View {
    @ObservedObject var plate: Plate
    @Binding var navigationPath: NavigationPath

    // Håller hela kalkyleringen
    @State private var calculation: String = ""

    // Håller det beräknade resultatet
    @State private var result: Double?

    var body: some View {
        GeometryReader { geometry in
            // Beräkna fontstorlekar och höjder baserat på skärmens storlek
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            let spacing: CGFloat = 1
            let columns: Int = 4
            let rows: Int = 4 // Antal rader i knapplayouten
            let totalSpacingWidth = spacing * CGFloat(columns + 1)
            let totalSpacingHeight = spacing * CGFloat(rows + 1)

            let availableWidth = screenWidth - totalSpacingWidth
            let availableHeight = screenHeight - totalSpacingHeight - 10 // Justera för inmatningsfältet

            let buttonWidth = availableWidth / CGFloat(columns)
            let buttonHeight = availableHeight / CGFloat(rows)

            // Anpassa fontstorlekar
            let inputFontSize = screenHeight * 0.08 // Ökad fontstorlek för uträkningen
            let buttonFontSize = buttonHeight * 0.4

            VStack(spacing: 1) {
                // Inmatningsfält som visar hela kalkyleringen
                Text(calculation.isEmpty ? " " : calculation)
                    .font(.system(size: inputFontSize))
                    .frame(height: screenHeight * 0.12, alignment: .trailing) // Justerad höjd för inmatningsfältet
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundColor(.white)
                    .background(Color.black)
                    .cornerRadius(5)

                // Kalkylatorns knappnät
                VStack(spacing: spacing) {
                    // Rad 1
                    HStack(spacing: spacing) {
                        CalculatorButton(label: "7", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) {
                            appendToCalculation("7")
                        }
                        CalculatorButton(label: "8", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) {
                            appendToCalculation("8")
                        }
                        CalculatorButton(label: "9", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) {
                            appendToCalculation("9")
                        }
                        // Plus/Minus-knapp med långtryck
                        CalculatorButtonWithLongPress(label: "+\n-", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: .orange) {
                            appendToCalculation("+")
                        } longPressAction: {
                            appendToCalculation("-")
                        }
                    }
                    // Rad 2
                    HStack(spacing: spacing) {
                        CalculatorButton(label: "4", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) {
                            appendToCalculation("4")
                        }
                        CalculatorButton(label: "5", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) {
                            appendToCalculation("5")
                        }
                        CalculatorButton(label: "6", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) {
                            appendToCalculation("6")
                        }
                        CalculatorButton(label: "×", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: .orange) {
                            appendToCalculation("×")
                        }
                    }
                    // Rad 3
                    HStack(spacing: spacing) {
                        CalculatorButton(label: "1", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) {
                            appendToCalculation("1")
                        }
                        CalculatorButton(label: "2", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) {
                            appendToCalculation("2")
                        }
                        CalculatorButton(label: "3", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) {
                            appendToCalculation("3")
                        }
                        CalculatorButton(label: "÷", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: .orange) {
                            appendToCalculation("÷")
                        }
                    }
                    // Rad 4
                    HStack(spacing: spacing) {
                        // Kommaknapp istället för minusknapp
                        CalculatorButton(label: ",", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) {
                            appendComma()
                        }
                        CalculatorButton(label: "0", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) {
                            appendToCalculation("0")
                        }
                        // Bakåtknapp
                        CalculatorButton(label: "⌫", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) {
                            backspace()
                        }
                        // "OK"-knappen
                        CalculatorButton(label: "OK", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: .blue) {
                            if let value = result {
                                addResultToPlate(value: value)
                            }
                        }
                    }
                }
                .padding(.horizontal, spacing)
            }
            .background(Color.black.edgesIgnoringSafeArea(.all))
        }
        // Visar resultatet i navigationstiteln
        .navigationTitle("Resultat: \(formatResult(result))")
        .navigationBarTitleDisplayMode(.inline) // Minskar mellanrummet mellan rubrik och innehåll
        // Uppdaterad onChange-syntax för watchOS 10.0
        .onChange(of: calculation) { newValue, oldValue in
            calculateResult()
        }
    }

    // MARK: - Kalkylatorfunktioner

    func appendToCalculation(_ value: String) {
        calculation += value
    }

    func appendComma() {
        let operators = ["+", "-", "*", "/"]
        
        // Kontrollera att det senaste tecknet inte är en operator
        if let lastChar = calculation.last, operators.contains(String(lastChar)) {
            // Förhindra att kommatecken läggs direkt efter en operator
            return
        }

        // Definiera operatorer för att separera tal
        var lastNumber = calculation
        for op in operators {
            if let range = calculation.range(of: op, options: .backwards) {
                lastNumber = String(calculation[range.upperBound...])
            }
        }

        // Kontrollera om det senaste talet redan innehåller ett kommatecken
        if !lastNumber.contains(",") {
            calculation += ","
        }
    }

    func backspace() {
        if !calculation.isEmpty {
            calculation.removeLast()
        }
    }

    func calculateResult() {
        guard !calculation.isEmpty else {
            result = nil
            return
        }

        // Ersätt specialtecken med standardoperatorer och hantera decimalseparatör
        let expressionString = calculation
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: ",", with: ".") // Hantera kommatecken som decimalseparatör

        // Kontrollera att uttrycket inte slutar med en operator eller decimalpunkt
        let operators = ["+", "-", "*", "/"]
        if let lastChar = expressionString.last, operators.contains(String(lastChar)) || lastChar == "." {
            // Utvärdera inte ofullständiga uttryck
            result = nil
            return
        }

        // Kontrollera att uttrycket endast innehåller tillåtna tecken (siffror och operatorer)
        let allowedCharacters = CharacterSet(charactersIn: "0123456789+-*/().")
        if expressionString.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
            // Uttrycket innehåller ogiltiga tecken
            result = nil
            return
        }

        // Använd NSExpression för att utvärdera uttrycket
        let expression = NSExpression(format: expressionString)
        if let value = expression.expressionValue(with: nil, context: nil) as? NSNumber {
            result = value.doubleValue
        } else {
            result = nil
        }
    }

    func addResultToPlate(value: Double) {
        let foodItem = FoodItem(
            name: "Kalkylator",
            carbsPer100g: 100,
            grams: value,
            gramsPerDl: nil,
            styckPerGram: nil,
            inputUnit: "g",
            isDefault: false,
            hasBeenLogged: false,
            isFavorite: false
        )
        plate.addItem(foodItem)
        // Navigera tillbaka till tallriken
        navigationPath = NavigationPath([Route.plateView])
    }

    func formatResult(_ value: Double?) -> String {
        if let value = value {
            if value.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0f", value)
            } else {
                return String(format: "%.2f", value)
            }
        } else {
            return ""
        }
    }
}

// Anpassad knappvy med långtryck för operatorer
struct CalculatorButtonWithLongPress: View {
    let label: String
    let width: CGFloat
    let height: CGFloat
    let fontSize: CGFloat
    var backgroundColor: Color = Color.gray
    let shortPressAction: () -> Void
    let longPressAction: () -> Void

    @State private var isLongPressActive = false

    var body: some View {
        Button(action: {
            if !isLongPressActive {
                shortPressAction()
            }
            isLongPressActive = false
        }) {
            Text(label)
                .font(.system(size: fontSize))
                .multilineTextAlignment(.center)
                .frame(width: width, height: height)
                .foregroundColor(.white)
                .background(backgroundColor)
                .cornerRadius(5)
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    longPressAction()
                    isLongPressActive = true
                }
        )
        .buttonStyle(PlainButtonStyle())
    }
}

// Anpassad knappvy
struct CalculatorButton: View {
    let label: String
    let width: CGFloat
    let height: CGFloat
    let fontSize: CGFloat
    var backgroundColor: Color = Color.gray
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: fontSize))
                .frame(width: width, height: height)
                .foregroundColor(.white)
                .background(backgroundColor)
                .cornerRadius(5)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
