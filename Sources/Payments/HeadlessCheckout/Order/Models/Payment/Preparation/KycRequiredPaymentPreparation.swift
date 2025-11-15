public struct KycRequiredPaymentPreparation: Codable, Sendable {
    public struct Kyc: Codable, Sendable {
        public enum Provider: String, Codable, Sendable {
            case persona
        }

        public var provider: Provider
        public var templateId: String
        public var referenceId: String
    }

    public var kyc: Kyc
}
