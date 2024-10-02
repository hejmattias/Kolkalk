import SwiftUI

struct ImportInstructionsView: View {
    var body: some View {
        VStack {
            Text("Importera livsmedel från CSV")
                .font(.headline)
                .padding()

            Text("För att importera livsmedel, vänligen öppna appen på din iPhone och tryck på 'Skicka CSV till Apple Watch'.")
                .multilineTextAlignment(.center)
                .padding()

            Spacer()
        }
        .navigationTitle("Importera")
    }
}
