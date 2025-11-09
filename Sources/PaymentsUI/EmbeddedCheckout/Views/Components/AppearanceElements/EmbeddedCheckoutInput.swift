import SwiftUI
import Utils

struct EmbeddedCheckoutInput: View {
    @Binding var text: String
    var placeholder: String = ""
    var isLoading: Bool = false
    var errorMessage: String?
    var keyboardType: UIKeyboardType = .default
    var contentType: UITextContentType?
    var isSecure: Bool = false
    var onEditingChanged: (Bool) -> Void = { _ in }
    var onCommit: () -> Void = {}

    private var placeholderColor: Color {
        Color(hex: "#67797F")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isSecure {
                SecureField("", text: $text, onCommit: onCommit)
                    .placeholder(when: text.isEmpty) {
                        Text(placeholder).foregroundColor(placeholderColor)
                    }
                    .modifier(InputModifier(isLoading: isLoading, hasError: errorMessage != nil))
            } else {
                TextField(
                    "", text: $text, onEditingChanged: onEditingChanged, onCommit: onCommit
                )
                .placeholder(when: text.isEmpty) {
                    Text(placeholder).foregroundColor(placeholderColor)
                }
                .keyboardType(keyboardType)
                .autocorrectionDisabled()
                .textContentType(contentType)
                .modifier(InputModifier(isLoading: isLoading, hasError: errorMessage != nil))
            }

            if let errorMessage = errorMessage, !errorMessage.isEmpty {
                EmbeddedCheckoutFormErrorMessage(errorMessage: errorMessage)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// Extension to add custom placeholder with styling
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            self
            if shouldShow {
                placeholder()
                    .allowsHitTesting(false)
            }
        }
    }
}

struct InputModifier: ViewModifier {
    let isLoading: Bool
    let hasError: Bool

    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        hasError ? Color.red : Color(hex: "#D0D5DD"),
                        lineWidth: 1
                    )
            )
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isLoading ? Color(hex: "#F4F5F6") : Color.white)
            )
            .disabled(isLoading)
            .opacity(isLoading ? 0.7 : 1)
    }
}

struct EmbeddedCheckoutFormErrorMessage: View {
    let errorMessage: String

    var body: some View {
        Text(errorMessage)
            .font(.system(size: 12))
            .foregroundColor(.red)
            .padding(.horizontal, 4)
            .padding(.top, 2)
    }
}

#Preview {
    VStack(spacing: 16) {
        EmbeddedCheckoutInput(
            text: .constant(""),
            placeholder: "Normal Input"
        )

        EmbeddedCheckoutInput(
            text: .constant(""),
            placeholder: "Loading Input",
            isLoading: true
        )

        EmbeddedCheckoutInput(
            text: .constant(""),
            placeholder: "Error Input",
            errorMessage: "This field is required"
        )

        EmbeddedCheckoutInput(
            text: .constant(""),
            placeholder: "Password",
            isSecure: true
        )
    }
    .padding()
}
