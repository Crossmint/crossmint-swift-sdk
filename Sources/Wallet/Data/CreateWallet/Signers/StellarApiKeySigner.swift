//
//  StellarApiKeySigner.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 12/22/25.
//

import CrossmintCommonTypes

public final class StellarApiKeySigner: ApiKeySigner, @unchecked Sendable {
    public init() {
        super.init(
            adminSigner: ApiKeySignerData()
        )
    }
}
