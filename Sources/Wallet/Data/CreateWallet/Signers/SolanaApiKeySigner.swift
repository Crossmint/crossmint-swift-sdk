import CrossmintCommonTypes

public final class SolanaApiKeySigner: ApiKeySigner, @unchecked Sendable {
    public init() {
        super.init(
            adminSigner: ApiKeySignerData()
        )
    }
}
