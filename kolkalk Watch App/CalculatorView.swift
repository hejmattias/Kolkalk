// Kolkalk/kolkalk Watch App/CalculatorView.swift

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

    // --- NYA KONSTANTER FÖR OPERATORER ---
    private let operators = ["+", "-", "×", "÷"]
    // --- SLUT NYA KONSTANTER ---

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
            let availableHeight = screenHeight - totalSpacingHeight //- 10 // Adjust for input field

            let buttonWidth = availableWidth / CGFloat(columns)
            let buttonHeight = availableHeight / CGFloat(rows)

            // Adjust font sizes
            let inputFontSize = screenHeight * 0.1 // Increased font size for the calculation
            let buttonFontSize = buttonHeight * 0.4

            VStack(spacing: 1) {
                // Input field displaying the entire calculation
                Text(calculation.isEmpty ? " " : calculation)
                    .font(.system(size: inputFontSize))
                    .frame(height: screenHeight * 0.1, alignment: .trailing) // Adjusted height for input field
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .lineLimit(1)
                    //.minimumScaleFactor(0.5)
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
                            } else if !calculation.isEmpty {
                                // Försök beräkna igen om resultatet var nil men calculation inte är tom
                                calculateResult(finalAttempt: true)
                                if let finalValue = result {
                                     addResultToPlate(value: finalValue)
                                }
                            }
                        }
                    }
                }
            }
           // .background(Color.black.edgesIgnoringSafeArea(.all))
        }
        // Set the navigation title with emoji
        .navigationTitle(navigationTitleWithIcons())
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: calculation) {
            calculateResult()
        }
        .onAppear {
            calculateResult()
        }
    }

    // Function to create the navigation title with icons
    func navigationTitleWithIcons() -> String {
        let resultString = " \(formatResult(result))"

        if shouldEmptyPlate {
            // Include trash and plus emoji
            return "🗑️➕ \(resultString)"
        } else {
            // Include only plus emoji
            return "➕ \(resultString)"
        }
    }

    // MARK: - Calculator Functions

    func appendToCalculation(_ value: String) {
        // *** ÄNDRING START: Lägg till kontroller för operatorer och kommatecken ***
        let lastChar = calculation.last

        // 1. Förhindra att lägga till operator om sista tecknet är en operator eller tomt
        if operators.contains(value) && (calculation.isEmpty || (lastChar != nil && operators.contains(String(lastChar!)))) {
             return // Gör ingenting
        }

        // 2. Förhindra att lägga till operator om sista tecknet är ett kommatecken
        if operators.contains(value) && lastChar == "," {
             return // Gör ingenting
        }
        // *** ÄNDRING SLUT ***

        calculation += value
    }


    func appendComma() {
        // *** ÄNDRING START: Förenklad logik för kommatecken ***
        guard !calculation.isEmpty else {
             calculation = "0," // Om tomt, börja med "0,"
             return
        }

        let lastChar = calculation.last! // Vi vet att den inte är tom här

        // Om sista tecknet är en operator, lägg till "0,"
        if operators.contains(String(lastChar)) {
             calculation += "0,"
             return
        }

        // Hitta sista nummersegmentet
        var lastNumberSegment = ""
        for char in calculation.reversed() {
            if operators.contains(String(char)) {
                break // Sluta när vi hittar en operator
            }
            lastNumberSegment.insert(char, at: lastNumberSegment.startIndex)
        }

        // Lägg bara till kommatecken om sista nummersegmentet inte redan har ett
        if !lastNumberSegment.contains(",") {
             calculation += ","
        }
        // *** ÄNDRING SLUT ***
    }

    func backspace() {
        if !calculation.isEmpty {
            calculation.removeLast()
        }
    }

    // *** ÄNDRING: Modifierad calculateResult för att hantera ofullständiga uttryck bättre ***
    func calculateResult(finalAttempt: Bool = false) {
        guard !calculation.isEmpty else {
            result = nil
            return
        }

        var expressionString = calculation
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: ",", with: ".") // Hantera komma som decimal

        // 1. Ta bort eventuell avslutande operator eller punkt
        let operatorsAndDot = CharacterSet(charactersIn: "+-*/.")
        while let lastChar = expressionString.last, operatorsAndDot.contains(lastChar.unicodeScalars.first!) {
             // Om vi inte är i ett sista försök (OK-knappen), sätt result till nil
             if !finalAttempt {
                 result = nil
                 return // Utvärdera inte om den slutar med operator/punkt (förutom vid OK)
             }
             // Annars (vid OK), ta bort det sista tecknet och fortsätt
             expressionString.removeLast()
             // Om strängen blir tom efter borttagning
             if expressionString.isEmpty {
                 result = nil
                 return
             }
        }

        // --- Förenklad utvärdering, litar mer på NSExpression ---
        // Kontrollera bara om strängen är tom efter eventuell sanering
        guard !expressionString.isEmpty else {
            result = nil
            return
        }

        // 2. Försök utvärdera med NSExpression
        let expression = NSExpression(format: expressionString)
        // Använd do-catch för att fånga eventuella fel från NSExpression
        do {
            if let value = try expression.expressionValue(with: nil, context: nil) as? NSNumber {
                result = value.doubleValue
            } else {
                 // Detta kan hända om uttrycket är giltigt men inte resulterar i ett tal (ovanligt här)
                 print("Calculator Error: Expression did not evaluate to a number: \(expressionString)")
                 result = nil
            }
        } catch {
             // NSExpression kastade ett fel (t.ex. ogiltig syntax som inte fångades ovan)
             print("Calculator Error: NSExpression evaluation failed for '\(expressionString)': \(error)")
             result = nil
        }
        // --- Slut förenklad utvärdering ---
    }
    // *** SLUT ÄNDRING calculateResult ***

    func addResultToPlate(value: Double) {
        if shouldEmptyPlate {
            plate.emptyPlate()
        }

        if var item = itemToEdit {
            // Update existing food item
            // *** ÄNDRING: Spara den *sanerade* calculation om resultatet användes ***
             item.name = calculation.trimmingCharacters(in: CharacterSet(charactersIn: "+-*/.,×÷")) // Spara den "rena" beräkningen
            item.grams = value
            plate.updateItem(item)
        } else {
            // Create new food item and mark it as a calculator item
            let foodItem = FoodItem(
                // *** ÄNDRING: Spara den *sanerade* calculation om resultatet användes ***
                name: calculation.trimmingCharacters(in: CharacterSet(charactersIn: "+-*/.,×÷")), // Spara den "rena" beräkningen
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
            // Använd NumberFormatter för att hantera lokal decimalavskiljare (komma)
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 0 // Inga decimaler om heltal
            formatter.maximumFractionDigits = 2 // Max 2 decimaler
            //formatter.decimalSeparator = "," // Kan behövas om systemets locale inte är svensk
            return formatter.string(from: NSNumber(value: value)) ?? ""
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
    var backgroundColor: Color = Color(white: 0.3) // Ändrad till mörkare grå som standard
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
