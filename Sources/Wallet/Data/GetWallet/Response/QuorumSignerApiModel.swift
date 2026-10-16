//
//  QuorumSignerApiModel.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 16/10/26.
//

import CrossmintCommonTypes
import Logger

public struct QuorumSignerApiModel: AdminSignerApiModel {
    public let type: AdminSignerDataType
    public let locator: String
    public let threshold: Int
    let members: [any AdminSignerApiModel]

    public var toDomain: any AdminSignerData {
        QuorumSignerData(
            id: String(locator.dropFirst("quorum:".count)),
            threshold: threshold,
            members: members.map(\.toDomain)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case type, locator, threshold, members
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(AdminSignerDataType.self, forKey: .type)
        locator = try container.decode(String.self, forKey: .locator)
        threshold = try container.decode(Int.self, forKey: .threshold)

        var list = try container.nestedUnkeyedContainer(forKey: .members)
        var members: [any AdminSignerApiModel] = []
        while !list.isAtEnd {
            let entry = try list.superDecoder()
            let rawType = try WalletConfigApiModel.rawSignerType(from: entry)
            guard let memberType = AdminSignerDataType(rawValue: rawType), memberType != .quorum else {
                Logger.smartWallet.warning(LogEvents.walletConfigQuorumMemberSkipped, attributes: [
                    "quorum": locator,
                    "type": rawType
                ])
                continue
            }
            members.append(try WalletConfigApiModel.decodeSigner(from: entry))
        }
        self.members = members
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(locator, forKey: .locator)
        try container.encode(threshold, forKey: .threshold)
        var list = container.nestedUnkeyedContainer(forKey: .members)
        for member in members {
            try list.encode(member)
        }
    }
}
