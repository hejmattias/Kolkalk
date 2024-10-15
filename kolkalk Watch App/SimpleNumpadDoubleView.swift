import SwiftUI

// 1. Definiera en Preference Key för att mäta Textens storlek
struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct SimpleNumpadDoubleView: View {
    @Binding var value: String
    var title: String
    @Environment(\.presentationMode) var presentationMode
    @State private var inputString: String = "0"
    let maxInputLength = 7 // Justera vid behov

    @State private var titleOffset: CGFloat = 0
    @State private var titleWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 4) {
                Spacer() // Flyttar ned back-knappen

                // Rullande rubrik med mask för fade-effekt
                ZStack(alignment: .leading) {
                    HStack(spacing: 50) { // Justera spacing för smidig loop
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.white)
                            .background(
                                GeometryReader { textGeometry in
                                    Color.clear
                                        .preference(key: SizePreferenceKey.self, value: textGeometry.size)
                                }
                            )
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .offset(x: titleOffset)
                    .onAppear {
                        // Starta animationen när vi har mätt textens bredd
                        DispatchQueue.main.async {
                            startTitleAnimation(totalWidth: titleWidth, geometryWidth: geometry.size.width * 0.45)
                        }
                    }
                }
                .frame(width: geometry.size.width * 0.45, height: 20)
                .clipped()
                .mask(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .black, location: 0.1),
                            .init(color: .black, location: 0.9),
                            .init(color: .clear, location: 1.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .background(Color.black)
                .padding(.horizontal)
                // Lägg till modifier för att läsa av textens storlek
                .onPreferenceChange(SizePreferenceKey.self) { size in
                    self.titleWidth = size.width
                }

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
                .padding(.top, 20)

                let buttonWidth = geometry.size.width / 5
                let buttonHeight = geometry.size.height / 10

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
        .navigationBarBackButtonHidden(true)
    }

    // 2. Funktion för att starta animationen
    func startTitleAnimation(totalWidth: CGFloat, geometryWidth: CGFloat) {
        // För att undvika division med noll
        guard totalWidth > 0 else { return }
        
        // Beräkna den totala rörelsebredden (dubbel rubrikens bredd + spacing)
        let totalMovement = totalWidth + 50 // 50 är spacing mellan HStack-elementen

        // Beräkna hastigheten (hastighet = totalMovement / duration)
        // Här sätter vi en konstant hastighet, t.ex. 30 punkter per sekund
        let speed: CGFloat = 30
        let duration = Double(totalMovement / speed)

        // Starta animationen
        withAnimation(Animation.linear(duration: duration).repeatForever(autoreverses: false)) {
            titleOffset = -totalMovement
        }
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
