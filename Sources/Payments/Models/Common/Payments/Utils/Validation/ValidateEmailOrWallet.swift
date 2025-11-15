import CrossmintCommonTypes
import Foundation
import Utils

public enum EmailOrWalletValidationResult {
    case valid
    case invalid(String)
}

public func validateEmailOrWallet(emailOrWallet: String, deliveryChain: Chain)
    -> EmailOrWalletValidationResult {
    if Address.validateAddressAndReturnAddress(
        emailOrWallet, chain: deliveryChain) == nil && !isValidEmail(emailOrWallet) {
        return .invalid(
            "Your email or \(deliveryChain.name) wallet address is invalid"
        )
    }

    return .valid
}

public func validateEmail(email: String) -> EmailOrWalletValidationResult {
    let errorPrefix = "Your email address is"
    if isEmpty(email) {
        return .invalid("\(errorPrefix) incomplete")
    }

    if !isValidEmail(email) {
        return .invalid("\(errorPrefix) invalid")
    }

    return .valid
}
