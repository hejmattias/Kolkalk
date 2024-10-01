import SwiftUI

struct SimpleNumpadDoubleView: View {
    @Binding var value: String
    var title: String
    @Environment(\.presentationMode) var presentationMode
    @State private var inputString: String = "0"
    let maxInputLength = 7 // Adjust as needed

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 4) {
                Spacer() // Flytta ned back-knappen

                HStack {
                    Button(action: {
                        self.presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.title3)
                    }
                    .buttonStyle(MinimalButtonStyle())
                    .frame(width: 30, height: 20)

                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: geometry.size.width * 0.45)

                    Spacer()
                }
                .padding(.horizontal)

                HStack {
                    Text(inputString)
                        .font(.system(size: 20))
                        .frame(maxWidth: geometry.size.width * 0.5, alignment: .leading)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Spacer()
                }
                .padding(.horizontal)

                let buttonWidth = geometry.size.width / 5
                let buttonHeight = geometry.size.height / 8

                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        CustomNumpadButton(label: "1", width: buttonWidth, height: buttonHeight, action: { appendNumber("1") })
                        CustomNumpadButton(label: "2", width: buttonWidth, height: buttonHeight, action: { appendNumber("2") })
                        CustomNumpadButton(label: "3", width: buttonWidth, height: buttonHeight, action: { appendNumber("3") })
                    }
                    HStack(spacing: 4) {
                        CustomNumpadButton(label: "4", width: buttonWidth, height: buttonHeight, action: { appendNumber("4") })
                        CustomNumpadButton(label: "5", width: buttonWidth, height: buttonHeight, action: { appendNumber("5") })
                        CustomNumpadButton(label: "6", width: buttonWidth, height: buttonHeight, action: { appendNumber("6") })
                    }
                    HStack(spacing: 4) {
                        CustomNumpadButton(label: "7", width: buttonWidth, height: buttonHeight, action: { appendNumber("7") })
                        CustomNumpadButton(label: "8", width: buttonWidth, height: buttonHeight, action: { appendNumber("8") })
                        CustomNumpadButton(label: "9", width: buttonWidth, height: buttonHeight, action: { appendNumber("9") })
                    }
                    HStack(spacing: 4) {
                        CustomNumpadButton(label: "⌫", width: buttonWidth, height: buttonHeight, action: { backspace() })
                        CustomNumpadButton(label: "0", width: buttonWidth, height: buttonHeight, action: { appendNumber("0") })
                        CustomNumpadButton(label: "OK", width: buttonWidth, height: buttonHeight, action: { confirm() })
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .edgesIgnoringSafeArea(.all)
        }
        .background(Color.black)
        .navigationBarBackButtonHidden(true) // Ta bort standardnavigeringskrysset
    }

    func appendNumber(_ number: String) {
        if inputString.count < maxInputLength {
            if inputString == "0" {
                inputString = number
            } else {
                inputString += number
            }
        }
    }

    func backspace() {
        if !inputString.isEmpty {
            inputString.removeLast()
            if inputString.isEmpty {
                inputString = "0"
            }
        }
    }

    func confirm() {
        if !inputString.isEmpty {
            value = inputString
            presentationMode.wrappedValue.dismiss()
        }
    }
}
