/// How a phone signer's one-time password reaches the user.
///
/// The channel is sent with every onboarding request. The signer service falls back to SMS when
/// none is requested, and it does not persist the choice, so it must be supplied again each time.
public enum OTPDeliveryChannel: String, Sendable, Codable {
    case sms
    case whatsapp
}
