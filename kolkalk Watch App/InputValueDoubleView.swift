import SwiftUI

struct InputValueDoubleView: View {
    @Binding var value: String
    var title: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        SimpleNumpadDoubleView(value: $value, title: title)
    }
}
