public enum BlockchainAddressError: Error {
    case invalidSolanaAddress(String)
    case invalidEVMAddress(String)
    case invalidCardanoAddress(String)
    case invalidSuiAddress(String)
    case invalidAptosAddress(String)
    case chainNotSupported(String)
}
