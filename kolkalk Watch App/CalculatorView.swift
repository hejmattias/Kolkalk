import SwiftUI

struct CalculatorView: View {
    @ObservedObject var plate: Plate
    @Binding var navigationPath: NavigationPath

    // Holds the entire calculation
    @State private var calculation: String = ""

    // Holds the calculated result
    @State private var result: Double?

    var body: some View {
        GeometryReader { geometry in
            // Calculate font sizes and heights based on screen size
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            let spacing: CGFloat = 1
            let columns: Int = 4
            let rows: Int = 4 // Number of rows in the button layout
            let totalSpacingWidth = spacing * CGFloat(columns + 1)
            let totalSpacingHeight = spacing * CGFloat(rows + 1)

            let availableWidth = screenWidth - totalSpacingWidth
            let availableHeight = screenHeight - totalSpacingHeight - 10 // Adjust for input field

            let buttonWidth = availableWidth / CGFloat(columns)
            let buttonHeight = availableHeight / CGFloat(rows)

            // Adjust font sizes
            let inputFontSize = screenHeight * 0.1 // Increased font size for the calculation
            let buttonFontSize = buttonHeight * 0.4

            VStack(spacing: 1) {
                // Input field displaying the entire calculation
                Text(calculation.isEmpty ? " " : calculation)
                    .font(.system(size: inputFontSize))
                    .frame(height: screenHeight * 0.12, alignment: .trailing) // Adjusted height for input field
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 1)
                    .padding(.vertical, 2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundColor(.white)
                    .background(Color.black)
                    .cornerRadius(5)

                // Calculator button grid
                VStack(spacing: spacing) {
                    // Row 1
                    HStack(spacing: spacing) {
                        CalculatorButton(label: "7", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, action: {
                            appendToCalculation("7")
                        })
                        CalculatorButton(label: "8", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, action: {
                            appendToCalculation("8")
                        })
                        CalculatorButton(label: "9", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, action: {
                            appendToCalculation("9")
                        })
                        CalculatorButton(label: "÷", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: .orange, action: {
                            appendToCalculation("÷")
                        })
                    }
                    // Row 2
                    HStack(spacing: spacing) {
                        CalculatorButton(label: "4", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, action: {
                            appendToCalculation("4")
                        })
                        CalculatorButton(label: "5", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, action: {
                            appendToCalculation("5")
                        })
                        CalculatorButton(label: "6", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, action: {
                            appendToCalculation("6")
                        })
                        CalculatorButton(label: "×", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: .orange, action: {
                            appendToCalculation("×")
                        })
                    }
                    // Row 3
                    HStack(spacing: spacing) {
                        CalculatorButton(label: "1", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, action: {
                            appendToCalculation("1")
                        })
                        CalculatorButton(label: "2", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, action: {
                            appendToCalculation("2")
                        })
                        CalculatorButton(label: "3", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, action: {
                            appendToCalculation("3")
                        })
                        CalculatorButton(label: "-", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: .orange, action: {
                            appendToCalculation("-")
                        })
                    }
                    // Row 4
                    HStack(spacing: spacing) {
                        CalculatorButton(label: "0", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, action: {
                            appendToCalculation("0")
                        })
                        // Backspace button that removes the last character
                        CalculatorButton(label: "⌫", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, action: {
                            backspace()
                        })
                        // "OK" button
                        CalculatorButton(label: "OK", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: .blue, action: {
                            if let value = result {
                                addResultToPlate(value: value)
                            }
                        })
                        CalculatorButton(label: "+", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: .orange, action: {
                            appendToCalculation("+")
                        })
                    }
                }
                .padding(.horizontal, spacing)
            }
            .background(Color.black.edgesIgnoringSafeArea(.all))
        }
        // Displays the result in the navigation title
        .navigationTitle("= \(formatResult(result))")
        .navigationBarTitleDisplayMode(.inline) // Reduces space between title and content
        // Calls calculateResult() whenever 'calculation' changes
        .onChange(of: calculation) {
            calculateResult()
        }
    }

    // MARK: - Calculator Functions

    func appendToCalculation(_ value: String) {
        calculation += value
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

        // Replace special characters with standard operators
        let expressionString = calculation.replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")

        // Check that the expression doesn't end with an operator
        let operators = ["+", "-", "*", "/"]
        if let lastChar = expressionString.last, operators.contains(String(lastChar)) {
            // Do not evaluate incomplete expressions
            result = nil
            return
        }

        // Check that the expression contains only allowed characters (digits and operators)
        let allowedCharacters = CharacterSet(charactersIn: "0123456789+-*/().")
        if expressionString.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
            // Expression contains invalid characters
            result = nil
            return
        }

        // Use NSExpression to evaluate the expression
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
        // Navigate back to the plate
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

// MARK: - CalculatorButton View

struct CalculatorButton: View {
    let label: String
    let width: CGFloat
    let height: CGFloat
    let fontSize: CGFloat
    var backgroundColor: Color = Color.gray // Number buttons have gray background
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
        .buttonStyle(PlainButtonStyle()) // Remove default button style
    }
}
