import CrossmintCommonTypes

public final class EVMApiKeySigner: ApiKeySigner, @unchecked Sendable {
    public init() {
        super.init(
            adminSigner: ApiKeySignerData()
        )
    }
}
