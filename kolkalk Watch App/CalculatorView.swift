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
    // --- Gäller endast numericInput ---
    @State private var calculationStarted: Bool = false

    var itemToEdit: FoodItem?
    var shouldEmptyPlate: Bool = false
    var mode: CalculatorMode // Viktig för att styra beteendet
    @Binding var outputString: String
    var inputTitle: String?
    @Environment(\.dismiss) var dismiss

    private let operators = ["+", "-", "×", "÷"]

    init(plate: Plate,
         navigationPath: Binding<NavigationPath>,
         mode: CalculatorMode, // Läget bestämmer beteendet
         outputString: Binding<String> = .constant(""),
         initialCalculation: String = "",
         itemToEdit: FoodItem? = nil,
         shouldEmptyPlate: Bool = false,
         inputTitle: String? = nil) {

        self._plate = ObservedObject(initialValue: plate)
        self._navigationPath = navigationPath
        self.mode = mode // Spara läget
        self._outputString = outputString

        var effectiveInitialCalculation = initialCalculation.isEmpty ? "0" : initialCalculation
        var startCalculationFlag = false // Temporär flagga för state-initiering

        // Nollställning och flagga för calculationStarted gäller bara numericInput
        if mode == .numericInput {
            let initialValue = Double(effectiveInitialCalculation.replacingOccurrences(of: ",", with: "."))
            if initialValue == 0.0 {
                effectiveInitialCalculation = "0"
            }
            // Sätt flaggan om initialvärdet inte är "0" i numericInput-läge
            if effectiveInitialCalculation != "0" {
                 startCalculationFlag = true
            }
        }

        self._calculation = State(initialValue: effectiveInitialCalculation)
        self.itemToEdit = itemToEdit
        self.shouldEmptyPlate = shouldEmptyPlate
        self.inputTitle = inputTitle

        _result = State(initialValue: calculateResultFromString(effectiveInitialCalculation))
        // Initiera calculationStarted baserat på flaggan (gäller bara numericInput)
        _calculationStarted = State(initialValue: startCalculationFlag)
    }

    var body: some View {
        GeometryReader { geometry -> AnyView in // Använd AnyView för att returnera från geometry
            // Layoutberäkningar (oförändrade)
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

             // Returnera AnyView som innehåller VStack
             return AnyView (
                 VStack(spacing: 1) {
                     // Inmatningsfält (oförändrat)
                     Text(calculation.isEmpty ? " " : calculation)
                         .font(.system(size: inputFontSize))
                         .frame(height: screenHeight * 0.1, alignment: .trailing)
                         .frame(maxWidth: .infinity, alignment: .trailing)
                         .lineLimit(1)
                         .foregroundColor(.white)
                         .background(Color.black)
                         .cornerRadius(5)

                     // Knappsats (oförändrad layout, anropar funktioner som sätter calculationStarted *om* mode är numericInput)
                     VStack(spacing: spacing) {
                         // Rad 1
                         HStack(spacing: spacing) {
                             CalculatorButton(label: "7", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) { appendToCalculation("7") }
                             CalculatorButton(label: "8", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) { appendToCalculation("8") }
                             CalculatorButton(label: "9", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) { appendToCalculation("9") }
                             CalculatorButtonWithLongPress(label: "+\n-", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: .orange) { appendToCalculation("+") } longPressAction: { appendToCalculation("-") }
                         }
                         // Rad 2
                         HStack(spacing: spacing) {
                             CalculatorButton(label: "4", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) { appendToCalculation("4") }
                             CalculatorButton(label: "5", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) { appendToCalculation("5") }
                             CalculatorButton(label: "6", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) { appendToCalculation("6") }
                             CalculatorButton(label: "×", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: .orange) { appendToCalculation("×") }
                         }
                         // Rad 3
                         HStack(spacing: spacing) {
                             CalculatorButton(label: "1", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) { appendToCalculation("1") }
                             CalculatorButton(label: "2", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) { appendToCalculation("2") }
                             CalculatorButton(label: "3", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize) { appendToCalculation("3") }
                             CalculatorButton(label: "÷", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: .orange) { appendToCalculation("÷") }
                         }
                         // Rad 4
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
                 .navigationTitle(navigationTitleText()) // Använder uppdaterad funktion
                 .navigationBarTitleDisplayMode(.inline)
                 .onChange(of: calculation) { oldValue, newValue in
                     result = calculateResultFromString(newValue)
                     // Återställ 'calculationStarted' om input blir "0" igen, *endast* i numericInput-läge
                     if mode == .numericInput && newValue == "0" {
                         calculationStarted = false
                     }
                 }
            ) // Slut på AnyView
        } // Slut på GeometryReader
    }

    // --- ANPASSAD FUNKTION FÖR TITEL START ---
    func navigationTitleText() -> String {
        let currentResult = result
        let resultString = formatResult(currentResult)
        let resultPrefix = "= "

        switch mode {
        case .plateCalculation:
            // Plate mode: Alltid grundtitel + resultat (om giltigt och inte 0)
            let baseTitle = shouldEmptyPlate ? "🗑️➕" : "➕"
            if !resultString.isEmpty, calculation != "0" {
                return "\(baseTitle) \(resultPrefix)\(resultString)" // Ex: "+ = 123,4"
            } else {
                return baseTitle // Ex: "+"
            }

        case .numericInput:
            // Numeric Input mode: Titel ändras baserat på calculationStarted
            let baseTitle = inputTitle ?? "Ange värde"

            // Om inget giltigt resultat ELLER calculation är "0", visa alltid grundtiteln
            guard !resultString.isEmpty, calculation != "0" else {
                return baseTitle // Ex: "Ange värde"
            }

            // Om det finns ett giltigt resultat:
            if calculationStarted {
                // Om inmatning påbörjad, visa bara resultatet
                return resultPrefix + resultString // Ex: "= 123,4"
            } else {
                // Om inmatning *inte* påbörjad (visar initialvärde), visa grundtitel + resultat
                return "\(baseTitle) \(resultPrefix)\(resultString)" // Ex: "Ange värde = 123,4"
            }
        }
    }
    // --- ANPASSAD FUNKTION FÖR TITEL SLUT ---


    // --- OK-KNAPP FUNKTION (Oförändrad) ---
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
        case .numericInput:
            var valueToSend: Double? = finalResult
            if valueToSend == nil {
                valueToSend = calculateResultFromString(calculation, finalAttempt: true)
            }
            outputString = formatResult(valueToSend ?? 0.0)
            dismiss()
        }
    }


    // MARK: - Calculator Functions

    func appendToCalculation(_ value: String) {
        // Sätt calculationStarted *endast* om vi är i numericInput-läge
        if mode == .numericInput && !calculationStarted && calculation == "0" {
            calculationStarted = true
        }

        let lastChar = calculation.last

        if calculation == "0" && !operators.contains(value) && value != "," {
            calculation = value
            return
        }

        // (Resten av logiken är oförändrad)
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
             if let last = lastChar, operators.contains(String(last)) {
                 calculation += "0"
             }
        }
        calculation += value
    }


    func appendComma() {
        // Sätt calculationStarted *endast* om vi är i numericInput-läge
        if mode == .numericInput && !calculationStarted {
            calculationStarted = true
        }
        appendToCalculation(",")
    }

    func backspace() {
        // Sätt calculationStarted *endast* om vi är i numericInput-läge
         if mode == .numericInput && !calculationStarted && calculation != "0" {
             calculationStarted = true
         }

        if !calculation.isEmpty {
            calculation.removeLast()
            if calculation.isEmpty {
                 calculation = "0"
                 // calculationStarted återställs i onChange om mode är numericInput
            }
        }
    }

    // Beräkningsfunktion (Oförändrad)
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
             print("Calculator Error: NSExpression evaluation failed for '\(expressionString)': \(error)")
             return nil
        }
    }

    // addResultToPlate (Oförändrad)
    func addResultToPlate(value: Double) {
        guard mode == .plateCalculation else { return }
        if shouldEmptyPlate { plate.emptyPlate() }
        let nameForPlate = calculation.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "+-*/.,×÷")))
        if var item = itemToEdit {
            item.name = nameForPlate.isEmpty ? String(format: "%.1f", value) : nameForPlate
            item.grams = value
            item.carbsPer100g = 100
            item.isCalculatorItem = true
            plate.updateItem(item)
        } else {
            let foodItem = FoodItem(
                name: nameForPlate.isEmpty ? String(format: "%.1f", value) : nameForPlate,
                carbsPer100g: 100,
                grams: value,
                inputUnit: "g",
                isCalculatorItem: true
            )
            plate.addItem(foodItem)
        }
        navigationPath = NavigationPath([Route.plateView])
    }

    // formatResult (Oförändrad)
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

// CalculatorButtonWithLongPress (Oförändrad)
struct CalculatorButtonWithLongPress: View {
    let label: String; let width: CGFloat; let height: CGFloat; let fontSize: CGFloat; var backgroundColor: Color = Color.gray; let shortPressAction: () -> Void; let longPressAction: () -> Void
    @State private var isLongPressActive = false
    var body: some View {
        Button(action: { if !isLongPressActive { shortPressAction() }; isLongPressActive = false }) {
            Text(label).font(.system(size: fontSize)).multilineTextAlignment(.center).frame(width: width, height: height).foregroundColor(.white).background(backgroundColor).cornerRadius(5)
        }.simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in longPressAction(); isLongPressActive = true }).buttonStyle(PlainButtonStyle())
    }
}

// CalculatorButton (Oförändrad)
struct CalculatorButton: View {
    let label: String; let width: CGFloat; let height: CGFloat; let fontSize: CGFloat; var backgroundColor: Color = Color(white: 0.3); let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label).font(.system(size: fontSize)).frame(width: width, height: height).foregroundColor(.white).background(backgroundColor).cornerRadius(5)
        }.buttonStyle(PlainButtonStyle())
    }
}
