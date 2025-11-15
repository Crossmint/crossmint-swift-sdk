import CrossmintCommonTypes
import Foundation

public struct SmartWalletConfigRequest: Codable {
    let chain: Chain
    public init(chain: Chain) {
        self.chain = chain
    }
}
