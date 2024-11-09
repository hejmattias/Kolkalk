// CalculatorView.swift

import SwiftUI

struct CalculatorView: View {
    @ObservedObject var plate: Plate
    @Binding var navigationPath: NavigationPath

    // Holds the entire calculation
    @State private var calculation: String

    // Holds the calculated result
    @State private var result: Double?

    var itemToEdit: FoodItem?
    var shouldEmptyPlate: Bool = false // Existing property

    init(plate: Plate, navigationPath: Binding<NavigationPath>, initialCalculation: String = "", itemToEdit: FoodItem? = nil, shouldEmptyPlate: Bool = false) {
        self._plate = ObservedObject(initialValue: plate)
        self._navigationPath = navigationPath
        self._calculation = State(initialValue: initialCalculation)
        self.itemToEdit = itemToEdit
        self.shouldEmptyPlate = shouldEmptyPlate // Initialize property
    }

    var body: some View {
        GeometryReader { geometry in
            // Calculate font sizes and heights based on screen size
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            let spacing: CGFloat = 1
            let columns: Int = 4
            let rows: Int = 4 // Number of rows in the keypad layout
            let totalSpacingWidth = spacing * CGFloat(columns + 1)
            let totalSpacingHeight = spacing * CGFloat(rows + 1)

            let availableWidth = screenWidth - totalSpacingWidth
            let availableHeight = screenHeight - totalSpacingHeight - 10 // Adjust for input field

            let buttonWidth = availableWidth / CGFloat(columns)
            let buttonHeight = availableHeight / CGFloat(rows)

            // Adjust font sizes
            let inputFontSize = screenHeight * 0.08 // Increased font size for the calculation
            let buttonFontSize = buttonHeight * 0.4

            VStack(spacing: 1) {
                // Input field displaying the entire calculation
                Text(calculation.isEmpty ? " " : calculation)
                    .font(.system(size: inputFontSize))
                    .frame(height: screenHeight * 0.12, alignment: .trailing) // Adjusted height for input field
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundColor(.white)
                    .background(Color.black)
                    .cornerRadius(5)

                // Calculator keypad
                VStack(spacing: spacing) {
                    // Row 1
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
                        // Plus/Minus button with long press
                        CalculatorButtonWithLongPress(label: "+\n-", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: .orange) {
                            appendToCalculation("+")
                        } longPressAction: {
                            appendToCalculation("-")
                        }
                    }
                    // Row 2
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
                    // Row 3
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
                    // Row 4
                    HStack(spacing: spacing) {
                        // Comma button
                        CalculatorButton(label: ",", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) {
                            appendComma()
                        }
                        CalculatorButton(label: "0", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) {
                            appendToCalculation("0")
                        }
                        // Backspace button
                        CalculatorButton(label: "⌫", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) {
                            backspace()
                        }
                        // "OK" button
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
        // Display the result in the navigation title with '-+' prefix if shouldEmptyPlate is true
        .navigationTitle("\(shouldEmptyPlate ? "-+ " : "")= \(formatResult(result))")
        .navigationBarTitleDisplayMode(.inline)
        // Updated 'onChange' closure for watchOS 10.0
        .onChange(of: calculation) {
            calculateResult()
        }
        .onAppear {
            calculateResult()
        }
    }

    // MARK: - Calculator Functions

    func appendToCalculation(_ value: String) {
        calculation += value
    }

    func appendComma() {
        let operators = ["+", "-", "×", "÷"]

        // Prevent comma from being added directly after an operator
        if let lastChar = calculation.last, operators.contains(String(lastChar)) {
            // Add "0," if the last character is an operator
            calculation += "0,"
            return
        }

        // Find the last operator in the expression
        var lastOperatorIndex: String.Index? = nil
        for op in operators {
            if let range = calculation.range(of: op, options: .backwards) {
                if let currentLast = lastOperatorIndex {
                    if range.lowerBound > currentLast {
                        lastOperatorIndex = range.lowerBound
                    }
                } else {
                    lastOperatorIndex = range.lowerBound
                }
            }
        }

        // Extract the last part of the expression after the last operator
        let lastNumber: String
        if let index = lastOperatorIndex {
            let afterOpIndex = calculation.index(after: index)
            if afterOpIndex < calculation.endIndex {
                lastNumber = String(calculation[afterOpIndex...])
            } else {
                lastNumber = ""
            }
        } else {
            lastNumber = calculation
        }

        // Check if the last number already contains a comma
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

        // Replace special characters with standard operators and handle decimal separator
        let expressionString = calculation
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: ",", with: ".") // Handle comma as decimal separator

        // Check that the expression doesn't end with an operator or decimal point
        let operators = ["+", "-", "*", "/"]
        if let lastChar = expressionString.last, operators.contains(String(lastChar)) || lastChar == "." {
            // Do not evaluate incomplete expressions
            result = nil
            return
        }

        // Check that the expression contains only allowed characters (numbers and operators)
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
        if shouldEmptyPlate {
            plate.emptyPlate()
        }

        if var item = itemToEdit {
            // Update existing food item
            item.name = calculation
            item.grams = value
            plate.updateItem(item)
        } else {
            // Create new food item and mark it as a calculator item
            let foodItem = FoodItem(
                name: calculation,
                carbsPer100g: 100,
                grams: value,
                gramsPerDl: nil,
                styckPerGram: nil,
                inputUnit: "g",
                isDefault: false,
                hasBeenLogged: false,
                isFavorite: false,
                isCalculatorItem: true // Mark as calculator item
            )
            plate.addItem(foodItem)
        }
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

// Custom button view with long press for operators
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

// Custom button view
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
