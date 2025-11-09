import SwiftUI

public struct PrimaryButton: View {
    public var text: String
    public var action: () -> Void
    public var isLoading: Bool
    public var isDisabled: Bool

    public var backgroundColor: Color = Color.green
    public var foregroundColor: Color = Color.white
    public var disabledOpacity: Double = 0.7
    public var cornerRadius: CGFloat = 8

    public init(
        text: String,
        action: @escaping () -> Void,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        backgroundColor: Color = Color.green,
        foregroundColor: Color = Color.white,
        disabledOpacity: Double = 0.7,
        cornerRadius: CGFloat = 8
    ) {
        self.text = text
        self.action = action
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.disabledOpacity = disabledOpacity
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
                        .frame(maxWidth: .infinity)
                } else {
                    Text(text)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(backgroundColor)
        .foregroundColor(foregroundColor)
        .cornerRadius(cornerRadius)
        .disabled(isDisabled || isLoading)
        .opacity((isDisabled || isLoading) ? disabledOpacity : 1)
    }
}

// MARK: - Preview
struct PrimaryButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            PrimaryButton(
                text: "Sign in",
                action: {},
                isLoading: false,
                isDisabled: false
            )

            PrimaryButton(
                text: "Sign in",
                action: {},
                isLoading: true,
                isDisabled: false
            )

            PrimaryButton(
                text: "Sign in",
                action: {},
                isLoading: false,
                isDisabled: true
            )

            PrimaryButton(
                text: "Verify",
                action: {},
                isLoading: false,
                isDisabled: false,
                backgroundColor: .blue
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
