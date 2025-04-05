// Kolkalk/kolkalk Watch App/CalculatorView.swift

import SwiftUI
import HealthKit // Importera HealthKit om det inte redan är gjort (för Plate etc.)

// <<< NYTT START >>>
enum CalculatorMode {
    case plateCalculation // Befintlig funktionalitet för tallriken
    case numericInput     // Nytt läge för att bara mata in ett värde
}
// <<< NYTT SLUT >>>

struct CalculatorView: View {
    // Befintliga @ObservedObject och @Binding
    @ObservedObject var plate: Plate
    @Binding var navigationPath: NavigationPath

    // Holds the entire calculation
    @State private var calculation: String

    // Holds the calculated result
    @State private var result: Double?

    // Befintliga optional properties
    var itemToEdit: FoodItem?
    var shouldEmptyPlate: Bool = false

    // --- NYA PROPERTIES START ---
    var mode: CalculatorMode // För att styra beteendet
    @Binding var outputString: String // För att skicka tillbaka värdet i numericInput-läge
    var inputTitle: String? // Valfri titel för numericInput-läge
    @Environment(\.dismiss) var dismiss // För att kunna stänga vyn
    // --- NYA PROPERTIES SLUT ---

    private let operators = ["+", "-", "×", "÷"]

    // --- ANPASSAD INIT START ---
    init(plate: Plate,
         navigationPath: Binding<NavigationPath>,
         mode: CalculatorMode, // Kräver läge
         outputString: Binding<String> = .constant(""), // Default tom binding
         initialCalculation: String = "",
         itemToEdit: FoodItem? = nil,
         shouldEmptyPlate: Bool = false,
         inputTitle: String? = nil) { // Ny valfri parameter

        self._plate = ObservedObject(initialValue: plate)
        self._navigationPath = navigationPath
        self.mode = mode // Sätt läget
        self._outputString = outputString // Sätt output binding
        self._calculation = State(initialValue: initialCalculation.isEmpty ? "0" : initialCalculation) // Starta med "0" om initial är tom
        self.itemToEdit = itemToEdit
        self.shouldEmptyPlate = shouldEmptyPlate
        self.inputTitle = inputTitle // Sätt valfri titel
    }
    // --- ANPASSAD INIT SLUT ---

    var body: some View {
        GeometryReader { geometry in
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

            VStack(spacing: 1) {
                // Inmatningsfält (visar beräkning eller resultat beroende på läge?)
                // Visar alltid 'calculation' för tydlighet
                Text(calculation.isEmpty ? " " : calculation)
                    .font(.system(size: inputFontSize))
                    .frame(height: screenHeight * 0.1, alignment: .trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .lineLimit(1)
                    .foregroundColor(.white)
                    .background(Color.black)
                    .cornerRadius(5)

                // Knappsats (oförändrad layout)
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
                         // <<< ANPASSAD OK-KNAPP START >>>
                         CalculatorButton(label: "OK", width: buttonWidth, height: buttonHeight, fontSize: buttonFontSize, backgroundColor: .blue) {
                             handleOkButton() // Anropa ny funktion
                         }
                         // <<< ANPASSAD OK-KNAPP SLUT >>>
                     }
                }
            }
        }
        .navigationTitle(navigationTitleText()) // Använd ny funktion för titel
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: calculation) {
            // Beräkna resultatet löpande, men bara för visning i titeln i plateCalculation-läge
             if mode == .plateCalculation {
                 calculateResult()
             } else {
                 // I numericInput-läge behöver vi inte nödvändigtvis uppdatera result för titeln
                 // Vi beräknar det slutgiltiga när OK trycks
                 result = nil // Nollställ här? Eller låt calculateResult(finalAttempt: true) hantera det vid OK.
             }
        }
        .onAppear {
            // Beräkna initialt resultat om det är plateCalculation-läge och det finns en initial beräkning
            if mode == .plateCalculation && !calculation.isEmpty && calculation != "0" {
                 calculateResult(finalAttempt: true) // Försök beräkna direkt
            } else if mode == .numericInput {
                // Om vi är i numericInput och initialCalculation är "0", behåll "0".
                // Om initialCalculation är ett annat tal, visa det.
                // Om initialCalculation är tomt (borde inte hända pga init), sätt "0".
                if calculation.isEmpty { calculation = "0" }
            }
        }
    }

    // --- ANPASSAD FUNKTION FÖR TITEL START ---
    func navigationTitleText() -> String {
        switch mode {
        case .plateCalculation:
            let resultString = " \(formatResult(result))" // Visa beräknat resultat
            if shouldEmptyPlate {
                return "🗑️➕ \(resultString)"
            } else {
                return "➕ \(resultString)"
            }
        case .numericInput:
            // Använd den givna titeln eller en standardtext
            return inputTitle ?? "Ange värde"
        }
    }
    // --- ANPASSAD FUNKTION FÖR TITEL SLUT ---


    // --- NY FUNKTION FÖR OK-KNAPP START ---
    func handleOkButton() {
        switch mode {
        case .plateCalculation:
            // Befintlig logik för att spara till tallrik
             calculateResult(finalAttempt: true) // Se till att resultatet är beräknat
            if let value = result {
                addResultToPlate(value: value)
            } else if !calculation.isEmpty {
                // Om calculation inte är tom men resultatet är nil, försök beräkna igen.
                // Detta hanteras redan i calculateResult(finalAttempt: true)
                // Om result fortfarande är nil efter finalAttempt, händer inget här.
            }
        case .numericInput:
            // Beräkna slutgiltigt resultat
            calculateResult(finalAttempt: true)
             // Uppdatera outputString med det formaterade resultatet (även om nil, blir tom sträng)
             outputString = formatResult(result ?? 0.0) // Skicka tillbaka 0 om nil? Eller ""? formatResult hanterar nil -> "".
             // Stäng vyn (.sheet)
             dismiss()
        }
    }
    // --- NY FUNKTION FÖR OK-KNAPP SLUT ---


    // MARK: - Calculator Functions (Mestadels oförändrade)

    func appendToCalculation(_ value: String) {
        let lastChar = calculation.last

        // Om calculation är "0" och vi lägger till en siffra, ersätt "0"
        if calculation == "0" && !operators.contains(value) && value != "," {
            calculation = value
            return
        }

        // Förhindra dubbla operatorer
        if operators.contains(value) && (calculation.isEmpty || (lastChar != nil && operators.contains(String(lastChar!)))) {
            // Ersätt sista operatorn om användaren trycker en ny direkt efter
            if !calculation.isEmpty && lastChar != nil && operators.contains(String(lastChar!)) {
                 calculation.removeLast()
                 calculation += value
            }
             return
        }
        // Förhindra operator direkt efter kommatecken
        if operators.contains(value) && lastChar == "," {
             return
        }
        // Förhindra flera kommatecken i samma tal-segment
        if value == "," {
             var segmentHasComma = false
             for char in calculation.reversed() {
                 if operators.contains(String(char)) { break }
                 if char == "," { segmentHasComma = true; break }
             }
             if segmentHasComma { return }
        }

        calculation += value
    }


    func appendComma() {
        guard !calculation.isEmpty else {
             calculation = "0,"
             return
        }
        let lastChar = calculation.last!
        if operators.contains(String(lastChar)) {
             calculation += "0,"
             return
        }
        // Förhindra dubbla kommatecken (redan i appendToCalculation)
        appendToCalculation(",")
    }

    func backspace() {
        if !calculation.isEmpty {
            calculation.removeLast()
            // Om det blir tomt, sätt tillbaka till "0"
            if calculation.isEmpty {
                 calculation = "0"
            }
        }
    }

    // calculateResult (Oförändrad logik, men anropas annorlunda)
    func calculateResult(finalAttempt: Bool = false) {
        guard !calculation.isEmpty else {
            result = nil
            return
        }

        var expressionString = calculation
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: ",", with: ".")

        let operatorsAndDot = CharacterSet(charactersIn: "+-*/.")
        while let lastChar = expressionString.last, operatorsAndDot.contains(lastChar.unicodeScalars.first!) {
             if !finalAttempt {
                 result = nil
                 return
             }
             expressionString.removeLast()
             if expressionString.isEmpty {
                 result = nil
                 return
             }
        }

        guard !expressionString.isEmpty else {
            result = nil
            return
        }

        // --- NSExpression utvärdering (oförändrad) ---
        let expression = NSExpression(format: expressionString)
        do {
            if let value = try expression.expressionValue(with: nil, context: nil) as? NSNumber {
                result = value.doubleValue
            } else {
                 print("Calculator Error: Expression did not evaluate to a number: \(expressionString)")
                 result = nil
            }
        } catch {
             print("Calculator Error: NSExpression evaluation failed for '\(expressionString)': \(error)")
             result = nil
        }
        // --- Slut NSExpression utvärdering ---
    }

    // addResultToPlate (Anropas endast i .plateCalculation mode)
    func addResultToPlate(value: Double) {
        guard mode == .plateCalculation else { return } // Säkerhetskoll

        if shouldEmptyPlate {
            plate.emptyPlate()
        }

        if var item = itemToEdit {
            // Uppdatera befintlig
             item.name = calculation.trimmingCharacters(in: CharacterSet(charactersIn: "+-*/.,×÷"))
            item.grams = value
            plate.updateItem(item)
        } else {
            // Skapa ny
            let foodItem = FoodItem(
                name: calculation.trimmingCharacters(in: CharacterSet(charactersIn: "+-*/.,×÷")),
                carbsPer100g: 100, // Standard för kalkylator
                grams: value,
                inputUnit: "g", // Standard för kalkylator
                isCalculatorItem: true // Markera
            )
            plate.addItem(foodItem)
        }
        // Navigera tillbaka till tallriken
        navigationPath = NavigationPath([Route.plateView])
    }

    // formatResult (Oförändrad)
    func formatResult(_ value: Double?) -> String {
         if let value = value {
             let formatter = NumberFormatter()
             formatter.numberStyle = .decimal
             formatter.minimumFractionDigits = 0
             formatter.maximumFractionDigits = 4 // Öka precisionen lite?
             formatter.decimalSeparator = "," // Använd komma som standard
             formatter.groupingSeparator = "" // Ingen tusentalsavgränsare
             return formatter.string(from: NSNumber(value: value)) ?? ""
         } else {
             return ""
         }
     }
}

// CalculatorButtonWithLongPress (Oförändrad)
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

// CalculatorButton (Oförändrad)
struct CalculatorButton: View {
    let label: String
    let width: CGFloat
    let height: CGFloat
    let fontSize: CGFloat
    var backgroundColor: Color = Color(white: 0.3)
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
