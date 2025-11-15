import SwiftUI

public struct CustomTextField: View {
    public var placeholder: String
    @Binding public var text: String
    public var keyboardType: UIKeyboardType = .default
    public var secure: Bool = false
    public var multilineTextAlignment: TextAlignment = .leading

    public var height: CGFloat = 40
    public var cornerRadius: CGFloat = 8
    public var borderColor: Color = Color(red: 0.886, green: 0.91, blue: 0.941)
    public var shadowColor: Color = Color(red: 0.063, green: 0.094, blue: 0.157).opacity(0.05)
    public var shadowRadius: CGFloat = 2
    public var shadowOffset: CGSize = CGSize(width: 0, height: 1)

    public init(
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default,
        secure: Bool = false,
        multilineTextAlignment: TextAlignment = .leading,
        height: CGFloat = 40,
        cornerRadius: CGFloat = 8,
        borderColor: Color = Color(red: 0.886, green: 0.91, blue: 0.941),
        shadowColor: Color = Color(red: 0.063, green: 0.094, blue: 0.157).opacity(0.05),
        shadowRadius: CGFloat = 2,
        shadowOffset: CGSize = CGSize(width: 0, height: 1)
    ) {
        self.placeholder = placeholder
        self._text = text
        self.keyboardType = keyboardType
        self.secure = secure
        self.multilineTextAlignment = multilineTextAlignment
        self.height = height
        self.cornerRadius = cornerRadius
        self.borderColor = borderColor
        self.shadowColor = shadowColor
        self.shadowRadius = shadowRadius
        self.shadowOffset = shadowOffset
    }

    public var body: some View {
        VStack {
            if secure {
                SecureField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .multilineTextAlignment(multilineTextAlignment)
                    .padding()
                    .frame(height: height)
                    .background(textFieldBackground)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .multilineTextAlignment(multilineTextAlignment)
                    .padding()
                    .frame(height: height)
                    .background(textFieldBackground)
            }
        }
    }

    private var textFieldBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(color: shadowColor, radius: shadowRadius, x: shadowOffset.width, y: shadowOffset.height)
    }
}

// MARK: - Preview
struct CustomTextField_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            CustomTextField(placeholder: "Standard TextField", text: .constant(""))

            CustomTextField(
                placeholder: "Email",
                text: .constant("user@example.com"),
                keyboardType: .emailAddress
            )

            CustomTextField(
                placeholder: "Password",
                text: .constant("password123"),
                secure: true
            )

            CustomTextField(
                placeholder: "Verification Code",
                text: .constant("123456"),
                keyboardType: .numberPad,
                multilineTextAlignment: .center
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
