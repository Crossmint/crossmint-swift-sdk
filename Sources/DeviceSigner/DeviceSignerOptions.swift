public enum BiometricPolicy: Sendable {
    case none
    case always
}

public struct DeviceSignerOptions: Sendable {
    public let biometricPolicy: BiometricPolicy

    public init(biometricPolicy: BiometricPolicy = .none) {
        self.biometricPolicy = biometricPolicy
    }
}
