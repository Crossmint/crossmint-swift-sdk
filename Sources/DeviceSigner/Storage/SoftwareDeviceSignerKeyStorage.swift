/// Backwards-compatible alias for ``KeychainKeyStorage``.
///
/// The software-backed key storage was renamed from `SoftwareDeviceSignerKeyStorage`
/// to ``KeychainKeyStorage`` in 0.12.0. This alias keeps the old name resolving so
/// React Native SDK releases that still reference `SoftwareDeviceSignerKeyStorage`
/// continue to build against the 0.12 line.
public typealias SoftwareDeviceSignerKeyStorage = KeychainKeyStorage
