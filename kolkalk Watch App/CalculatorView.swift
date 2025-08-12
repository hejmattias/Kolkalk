// Kolkalk/kolkalk Watch App/CalculatorView.swift

import SwiftUI
import HealthKit

enum CalculatorMode {
    case plateCalculation
    case numericInput
}

struct CalculatorView: View {
    @ObservedObject var plate: Plate
    @Binding var navigationPath: NavigationPath

    @State private var calculation: String
    @State private var result: Double?
    @State private var calculationStarted: Bool = false

    var itemToEdit: FoodItem?
    var shouldEmptyPlate: Bool = false
    var mode: CalculatorMode
    @Binding var outputString: String
    var inputTitle: String?
    @Environment(\.dismiss) var dismiss

    private let operators = ["+", "-", "×", "÷"]

    init(plate: Plate,
         navigationPath: Binding<NavigationPath>,
         mode: CalculatorMode,
         outputString: Binding<String> = .constant(""),
         initialCalculation: String = "",
         itemToEdit: FoodItem? = nil,
         shouldEmptyPlate: Bool = false,
         inputTitle: String? = nil) {

        self._plate = ObservedObject(initialValue: plate)
        self._navigationPath = navigationPath
        self.mode = mode
        self._outputString = outputString

        // Gamla beteendet: använd itemToEdit.name som kalkylsträng om det finns, annars initialCalculation eller "0"
        var effectiveInitialCalculation: String
        if let item = itemToEdit, item.isCalculatorItem {
            effectiveInitialCalculation = item.name
        } else if !initialCalculation.isEmpty {
            effectiveInitialCalculation = initialCalculation
        } else if let item = itemToEdit {
            effectiveInitialCalculation = item.name
        } else {
            effectiveInitialCalculation = "0"
        }

        var startCalculationFlag = false

        let potentialNumber = Double(effectiveInitialCalculation.replacingOccurrences(of: ",", with: "."))
        if potentialNumber != nil {
            effectiveInitialCalculation = effectiveInitialCalculation.formatForInitialDisplay()
        }

        if mode == .numericInput {
            let initialValueAfterFormat = Double(effectiveInitialCalculation.replacingOccurrences(of: ",", with: "."))
            if initialValueAfterFormat == 0.0 { }
            if effectiveInitialCalculation != "0" {
                 startCalculationFlag = true
            }
        }

        self._calculation = State(initialValue: effectiveInitialCalculation)
        self.itemToEdit = itemToEdit
        self.shouldEmptyPlate = shouldEmptyPlate
        self.inputTitle = inputTitle

        _result = State(initialValue: calculateResultFromString(effectiveInitialCalculation))
        _calculationStarted = State(initialValue: startCalculationFlag)
    }

    var body: some View {
        GeometryReader { geometry -> AnyView in
             let screenWidth = geometry.size.width
             let screenHeight = geometry.size.height
             let spacing: CGFloat = 1
             let columns: Int = 4
             let rows: Int = 4
             let totalSpacingWidth = spacing * CGFloat(columns + 1)
             let totalSpacingHeight = spacing * CGFloat(rows + 1)
             let availableWidth = screenWidth - totalSpacingWidth
             let availableHeight = screenHeight - totalSpacingHeight
             let buttonWidth = availableWidth / CGFloat(columns)
             let buttonHeight = availableHeight / CGFloat(rows)
             let inputFontSize = screenHeight * 0.1
             let buttonFontSize = buttonHeight * 0.4

             return AnyView (
                 VStack(spacing: 1) {
                     Text(calculation.isEmpty ? " " : calculation)
                         .font(.system(size: inputFontSize))
                         .frame(height: screenHeight * 0.1, alignment: .trailing)
                         .frame(maxWidth: .infinity, alignment: .trailing)
                         .lineLimit(1)
                         .foregroundColor(.white)
                         .background(Color.black)
                         .cornerRadius(5)
                     VStack(spacing: spacing) {
                         HStack(spacing: spacing) {
                             CalculatorButton(label: "7", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) { appendToCalculation("7") }
                             CalculatorButton(label: "8", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) { appendToCalculation("8") }
                             CalculatorButton(label: "9", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) { appendToCalculation("9") }
                             CalculatorButtonWithLongPress(label: "+\n-", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: .orange) { appendToCalculation("+") } longPressAction: { appendToCalculation("-") }
                         }
                         HStack(spacing: spacing) {
                             CalculatorButton(label: "4", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) { appendToCalculation("4") }
                             CalculatorButton(label: "5", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) { appendToCalculation("5") }
                             CalculatorButton(label: "6", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) { appendToCalculation("6") }
                             CalculatorButton(label: "×", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: .orange) { appendToCalculation("×") }
                         }
                         HStack(spacing: spacing) {
                             CalculatorButton(label: "1", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) { appendToCalculation("1") }
                             CalculatorButton(label: "2", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) { appendToCalculation("2") }
                             CalculatorButton(label: "3", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) { appendToCalculation("3") }
                             CalculatorButton(label: "÷", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: .orange) { appendToCalculation("÷") }
                         }
                         HStack(spacing: spacing) {
                             CalculatorButton(label: ",", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) { appendComma() }
                             CalculatorButton(label: "0", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) { appendToCalculation("0") }
                             CalculatorButton(label: "⌫", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) { backspace() }
                             CalculatorButton(label: "OK", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: .blue) {
                                 handleOkButton()
                             }
                         }
                    }
                 }
                 .navigationTitle(navigationTitleText())
                 .navigationBarTitleDisplayMode(.inline)
                 .onChange(of: calculation) { oldValue, newValue in
                     result = calculateResultFromString(newValue)
                     if mode == .numericInput && newValue == "0" {
                         calculationStarted = false
                     }
                 }
            )
        }
    }

    func navigationTitleText() -> String {
        let currentResult = result
        let resultString = formatResult(currentResult)
        let resultPrefix = "= "

        switch mode {
        case .plateCalculation:
            let baseTitle = shouldEmptyPlate ? "🗑️➕" : "➕"
            if !resultString.isEmpty, calculation != "0" {
                return "\(baseTitle) \(resultPrefix)\(resultString)"
            } else {
                return baseTitle
            }

        case .numericInput:
            let baseTitle = inputTitle ?? "Ange värde"
            guard !resultString.isEmpty, calculation != "0" else {
                return baseTitle
            }
            if calculationStarted {
                return resultPrefix + resultString
            } else {
                return "\(baseTitle) \(resultPrefix)\(resultString)"
            }
        }
    }

    func handleOkButton() {
    let finalResult = result
    switch mode {
    case .plateCalculation:
        if let value = finalResult {
            addResultToPlate(value: value)
        } else {
            let calculatedOnOK = calculateResultFromString(calculation, finalAttempt: true)
            if let value = calculatedOnOK {
                addResultToPlate(value: value)
            } else {
                print("Plate Calculation OK Error: Could not evaluate final calculation: \(calculation)")
            }
        }
        // Lägg till följande rad:
        dismiss() // <-- detta stänger CalculatorView om den är en sheet
    case .numericInput:
        var valueToSend: Double? = finalResult
        if valueToSend == nil {
            valueToSend = calculateResultFromString(calculation, finalAttempt: true)
        }
        let resultFormattedString = formatResult(valueToSend ?? 0.0)
        outputString = resultFormattedString.formatForInitialDisplay()
        dismiss()
    }
}

    // MARK: - Calculator Functions

    func appendToCalculation(_ value: String) {
        if mode == .numericInput && !calculationStarted && calculation == "0" && value != "," {
            calculationStarted = true
        }
        let lastChar = calculation.last

        if calculation == "0" && !operators.contains(value) && value != "," {
            calculation = value
            return
        }
        if calculation == "0" && value == "," {
            calculation = "0,"
            if mode == .numericInput && !calculationStarted {
                calculationStarted = true
            }
            return
        }
        if operators.contains(value) && (calculation.isEmpty || (lastChar != nil && operators.contains(String(lastChar!)))) {
            if !calculation.isEmpty && lastChar != nil && operators.contains(String(lastChar!)) {
                 calculation.removeLast()
                 calculation += value
            }
             return
        }
        if operators.contains(value) && lastChar == "," {
             return
        }
        if value == "," {
             var segmentHasComma = false
             for char in calculation.reversed() {
                 if operators.contains(String(char)) { break }
                 if char == "," { segmentHasComma = true; break }
             }
             if segmentHasComma { return }
             if calculation.isEmpty || (lastChar != nil && operators.contains(String(lastChar!))) {
                 calculation += "0"
             }
        }
        calculation += value
    }

    func appendComma() {
        if mode == .numericInput && !calculationStarted {
            calculationStarted = true
        }
        appendToCalculation(",")
    }

    func backspace() {
         if mode == .numericInput && !calculationStarted && calculation != "0" {
             calculationStarted = true
         }
        if !calculation.isEmpty {
            calculation.removeLast()
            if calculation.isEmpty {
                 calculation = "0"
            }
        }
    }

    func calculateResultFromString(_ calcString: String, finalAttempt: Bool = false) -> Double? {
        guard !calcString.isEmpty else { return nil }
        var expressionString = calcString.replacingOccurrences(of: "×", with: "*").replacingOccurrences(of: "÷", with: "/").replacingOccurrences(of: ",", with: ".")
        if !finalAttempt, let lastChar = expressionString.last, "+-*/.".contains(lastChar) { return nil }
        let operatorsAndDot = CharacterSet(charactersIn: "+-*/.")
        while finalAttempt, let lastChar = expressionString.last, operatorsAndDot.contains(lastChar.unicodeScalars.first!) {
             expressionString.removeLast()
             if expressionString.isEmpty { return nil }
        }
        guard !expressionString.isEmpty else { return nil }
        let expression = NSExpression(format: expressionString)
        do {
            let value = try expression.expressionValue(with: nil, context: nil) as? NSNumber
            return value?.doubleValue
        } catch {
            if let simpleDouble = Double(expressionString) {
                return simpleDouble
            }
             print("Calculator Error: NSExpression evaluation failed for '\(expressionString)' and not a simple double: \(error)")
             return nil
        }
    }

    // Återgå till att lagra kalkylsträngen i .name-fältet
    func addResultToPlate(value: Double) {
        guard mode == .plateCalculation else { return }
        if shouldEmptyPlate { plate.emptyPlate() }
        let calculationTrimmed = calculation.trimmingCharacters(in: .whitespacesAndNewlines)
        if var item = itemToEdit {
            item.name = calculationTrimmed // <-- Spara kalkylsträng som namn!
            item.grams = value
            item.carbsPer100g = 100
            item.isCalculatorItem = true
            item.inputUnit = "g"
            plate.updateItem(item)
        } else {
            let foodItem = FoodItem(
                name: calculationTrimmed, // <-- Spara kalkylsträng som namn!
                carbsPer100g: 100,
                grams: value,
                inputUnit: "g",
                isCalculatorItem: true
            )
            plate.addItem(foodItem)
        }
        navigationPath = NavigationPath([Route.plateView])
    }

    func formatResult(_ value: Double?) -> String {
         if let value = value {
             let formatter = NumberFormatter()
             formatter.numberStyle = .decimal
             formatter.minimumFractionDigits = 0
             formatter.maximumFractionDigits = 4
             formatter.decimalSeparator = ","
             formatter.groupingSeparator = ""
             return formatter.string(from: NSNumber(value: value)) ?? ""
         } else {
             return ""
         }
     }
}

struct CalculatorButtonWithLongPress: View {
    let label: String; let width: CGFloat; let height: CGFloat; let fontSize: CGFloat; var backgroundColor: Color = Color.gray; let shortPressAction: () -> Void; let longPressAction: () -> Void
    @State private var isLongPressActive = false
    var body: some View {
        Button(action: { if !isLongPressActive { shortPressAction() }; isLongPressActive = false }) {
            Text(label).font(.system(size: fontSize)).multilineTextAlignment(.center).frame(width: width, height: height).foregroundColor(.white).background(backgroundColor).cornerRadius(5)
        }.simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in longPressAction(); isLongPressActive = true }).buttonStyle(PlainButtonStyle())
    }
}

struct CalculatorButton: View {
    let label: String; let width: CGFloat; let height: CGFloat; let fontSize: CGFloat; var backgroundColor: Color = Color(white: 0.3); let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label).font(.system(size: fontSize)).frame(width: width, height: height).foregroundColor(.white).background(backgroundColor).cornerRadius(5)
        }.buttonStyle(PlainButtonStyle())
    }
}
