import CrossmintCommonTypes
import Foundation

public struct WalletConfig {
    let recoveryMethodsWithStatus: [RecoveryMethod]
    let signerQuorums: [QuorumSignerData]

    /// Every recovery signer of the wallet. Each one can authorize on its own.
    public var recoveryMethods: [AdminSignerData] { recoveryMethodsWithStatus.map(\.signer) }

    /// The first recovery signer of the wallet.
    public var recovery: AdminSignerData { recoveryMethodsWithStatus[0].signer }

    init(recovery: RecoveryMethod, others: [RecoveryMethod] = [], signerQuorums: [QuorumSignerData] = []) {
        recoveryMethodsWithStatus = [recovery] + others
        self.signerQuorums = signerQuorums
    }

    init(recovery: AdminSignerData) {
        self.init(recovery: RecoveryMethod(signer: recovery))
    }

    func recoverySigner<T: AdminSignerData>(ofType type: T.Type) -> T? {
        for method in recoveryMethods {
            if let match = method as? T { return match }
        }
        return nil
    }

    func containsRecoveryMethod(_ locator: SignerLocator) -> Bool {
        recoveryMethods.contains { (try? SignerLocator(from: $0.locator)) == locator }
    }

    func quorum(withMember locator: SignerLocator) -> QuorumSignerData? {
        for case let quorum as QuorumSignerData in recoveryMethods
        where quorum.members.contains(where: { (try? SignerLocator(from: $0.locator)) == locator }) {
            return quorum
        }
        return nil
    }

    func recoveryQuorumLocators(withMember locator: SignerLocator) -> [SignerLocator] {
        quorumLocators(withMember: locator, in: recoveryMethods.compactMap { $0 as? QuorumSignerData })
    }

    func quorumLocators(withMember locator: SignerLocator) -> [SignerLocator] {
        let recoveryQuorums = recoveryMethods.compactMap { $0 as? QuorumSignerData }
        return quorumLocators(withMember: locator, in: recoveryQuorums + signerQuorums)
    }

    private func quorumLocators(withMember locator: SignerLocator, in quorums: [QuorumSignerData]) -> [SignerLocator] {
        quorums
            .filter { quorum in quorum.members.contains { (try? SignerLocator(from: $0.locator)) == locator } }
            .map { SignerLocator.quorum(id: $0.id) }
    }

    func recoveryRole(of locator: SignerLocator, explicit: SignerLocator?) throws(WalletError) -> SignerLocator? {
        let quorums = recoveryQuorumLocators(withMember: locator)
        if let explicit {
            return quorums.contains(explicit) ? explicit : nil
        }
        if containsRecoveryMethod(locator) { return locator }
        guard quorums.count <= 1 else { throw .quorumSelectionAmbiguous(quorums: quorums) }
        return quorums.first
    }

    func recoveryLocator(actingFor locator: SignerLocator) -> SignerLocator? {
        if containsRecoveryMethod(locator) { return locator }
        guard let quorum = quorum(withMember: locator) else { return nil }
        return .quorum(id: quorum.id)
    }
}
