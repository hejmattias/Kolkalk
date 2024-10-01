import SwiftUI

struct SimpleNumpadView: View {
    @Binding var value: Int
    var title: String
    @Environment(\.presentationMode) var presentationMode
    @State private var inputString: String = ""

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.headline)

            Text(inputString)
                .font(.largeTitle)
                .padding()
                .frame(maxWidth: .infinity, alignment: .center)
                .background(Color.gray.opacity(0.2)) // Replaced UIColor with Color
                .cornerRadius(8)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Spacer()

            VStack(spacing: 10) {
                ForEach([["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]], id: \.self) { row in
                    HStack(spacing: 10) {
                        ForEach(row, id: \.self) { number in
                            NumpadButton(label: number) {
                                appendNumber(number)
                            }
                        }
                    }
                }
                HStack(spacing: 10) {
                    NumpadButton(label: "⌫") {
                        backspace()
                    }
                    NumpadButton(label: "0") {
                        appendNumber("0")
                    }
                    NumpadButton(label: "OK") {
                        confirm()
                    }
                }
            }
            Spacer()
        }
        .padding()
    }

    func appendNumber(_ number: String) {
        inputString += number
    }

    func backspace() {
        if !inputString.isEmpty {
            inputString.removeLast()
        }
    }

    func confirm() {
        if let intValue = Int(inputString) {
            value = intValue
            presentationMode.wrappedValue.dismiss()
        }
    }
}

struct NumpadButton: View {
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.title)
                .frame(minWidth: 40, minHeight: 40) // Adjusted size for watchOS
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
        }
    }
}
