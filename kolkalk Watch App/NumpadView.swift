import SwiftUI

// Anpassad knappstil för små knappar med minimal kant
struct MinimalButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.clear)
            .foregroundColor(.gray)
            .cornerRadius(4)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// Anpassad knappstil för sifferknappar
struct CustomButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Color.gray)
            .foregroundColor(.white)
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .shadow(color: .clear, radius: 0)
    }
}

struct NumpadView: View {
    @Binding var value: Int
    @Environment(\.presentationMode) var presentationMode
    @State private var inputString: String = "0"
    var foodName: String
    var carbsPer100g: Double // Kolhydrater per 100g
    var gramsPerDl: Double?  // Gram per dl
    var styckPerGram: Double?  // Gram per styck
    var onConfirm: (Double, String) -> Void

    @State private var unit: String = "g"
    let maxInputLength = 5 // Max antal siffror som tillåts

    @State private var titleOffset: CGFloat = 0
    @State private var titleWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 4) {
                Spacer() // Flyttar ned back-knappen

                HStack {
                    Button(action: {
                        self.presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.title3)
                    }
                    .buttonStyle(MinimalButtonStyle())
                    .frame(width: 30, height: 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {  // Lägg till mellanrum mellan upprepningarna
                            Text(foodName)
                                .font(.headline)
                                .foregroundColor(.white)
                                .fixedSize(horizontal: true, vertical: false)
                            Text(foodName)
                                .font(.headline)
                                .foregroundColor(.white)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .offset(x: titleOffset, y: 0)
                        .frame(height: 20)
                        .background(GeometryReader { geo in
                            Color.clear.onAppear {
                                titleWidth = geo.size.width / 2  // Dela med 2 eftersom vi har två kopior av texten
                            }
                        })
                    }
                    .frame(width: geometry.size.width * 0.45)
                    .clipped()
                    .onAppear {
                        animateTitle(viewWidth: geometry.size.width * 0.45)
                    }

                    Spacer()
                }
                .padding(.horizontal)

                HStack {
                    Text("\(inputString)\(unit)")
                        .font(.system(size: 20))
                        .frame(maxWidth: geometry.size.width * 0.5, alignment: .leading)
                        .foregroundColor(.white)
                        .onTapGesture {
                            toggleUnit()
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Spacer()

                    Text("\(calculatedCarbs(), specifier: "%.1f")gk")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(maxWidth: geometry.size.width * 0.5, alignment: .trailing)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
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
                        // Knapp med långtryck för kommatecken
                        CustomNumpadButtonWithLongPress(label: "0\n,", width: buttonWidth, height: buttonHeight, shortPressAction: {
                            appendNumber("0")
                        }, longPressAction: {
                            appendComma()
                        })
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
        .navigationBarBackButtonHidden(true) // Tar bort standardnavigeringskrysset
    }

    func animateTitle(viewWidth: CGFloat) {
        withAnimation(Animation.linear(duration: Double(titleWidth) * 0.05).repeatForever(autoreverses: false)) {
            titleOffset = -titleWidth
        }
    }

    func toggleUnit() {
        if unit == "g" {
            if gramsPerDl != nil {
                unit = "dl"
            } else if styckPerGram != nil {
                unit = "st"
            }
        } else if unit == "dl" {
            if styckPerGram != nil {
                unit = "st"
            } else {
                unit = "g"
            }
        } else {
            unit = "g"
        }
    }

    func calculatedCarbs() -> Double {
        let inputValue = Double(inputString.replacingOccurrences(of: ",", with: ".")) ?? 0

        if unit == "g" {
            // Kolhydrater baserat på gram
            return (carbsPer100g / 100) * inputValue
        } else if unit == "dl", let gramsPerDl = gramsPerDl {
            // Kolhydrater baserat på deciliter
            return (carbsPer100g / 100) * gramsPerDl * inputValue
        } else if unit == "st", let styckPerGram = styckPerGram {
            // Kolhydrater baserat på styck
            return (carbsPer100g / 100) * styckPerGram * inputValue
        }
        return 0
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

    func appendComma() {
        if !inputString.contains(",") && inputString.count < maxInputLength {
            inputString += ","
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
        let sanitizedInput = inputString.replacingOccurrences(of: ",", with: ".")
        if let doubleValue = Double(sanitizedInput) {
            onConfirm(doubleValue, unit)
            self.presentationMode.wrappedValue.dismiss()
        }
    }
}

// Anpassad knappvy med dynamisk bredd och höjd
struct CustomNumpadButton: View {
    let label: String
    let width: CGFloat
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.title3)
                .frame(width: width, height: height)
        }
        .buttonStyle(CustomButtonStyle())
    }
}

// Anpassad knapp med långtryck
struct CustomNumpadButtonWithLongPress: View {
    let label: String
    let width: CGFloat
    let height: CGFloat
    let shortPressAction: () -> Void
    let longPressAction: () -> Void

    var body: some View {
        Button(action: {
            shortPressAction()
        }) {
            Text(label)
                .font(.title3)
                .multilineTextAlignment(.center)
                .frame(width: width, height: height)
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                longPressAction()
            }
        )
        .buttonStyle(CustomButtonStyle())
    }
}
