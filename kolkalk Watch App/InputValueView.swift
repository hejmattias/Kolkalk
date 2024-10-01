import Foundation
import SwiftUI

struct InputValueView: View {
    @Binding var value: Int
    var title: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        SimpleNumpadView(value: $value, title: title)
    }
}
