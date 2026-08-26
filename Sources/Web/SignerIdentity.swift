import CrossmintCommonTypes

/// Who the non-custodial signer service must send a one-time password to.
public enum SignerIdentity: Sendable, Equatable {
    case email(String)
    case phone(String, channel: OTPDeliveryChannel?)

    package var authId: String {
        switch self {
        case .email(let email): "email:\(email)"
        case .phone(let phone, _): "phone:\(phone)"
        }
    }

    package var channel: OTPDeliveryChannel? {
        guard case .phone(_, let channel) = self else { return nil }
        return channel
    }
}
