public enum Chain: AnyChain, Equatable, Sendable, Hashable {
    public init(_ from: String) {
        let types: [any SpecificChain.Type] = [
            EVMChain.self, SolanaChain.self, StellarChain.self
        ]

        let firstMatchingTypeThatProducesAValidChain = types.compactMap { type in
            type.init(from)
        }.first

        self = firstMatchingTypeThatProducesAValidChain?.chain ?? .unknown(name: from)
    }

    case ethereum
    case polygon
    case bsc
    case optimism
    case arbitrum
    case base
    case zora
    case arbitrumnova
    case astarZkevm
    case apechain
    case apex
    case boss
    case coti
    case lightlink
    case skaleNebula
    case seiPacific1
    case chiliz
    case avalanche
    case xai
    case shape
    case rari
    case scroll
    case viction
    case mode
    case space
    case soneium
    case story
    case arbitrumSepolia
    case avalancheFuji
    case curtis
    case barretTestnet
    case baseGoerli
    case baseSepolia
    case bscTestnet
    case chilizSpicyTestnet
    case cotiTestnet
    case ethereumGoerli
    case ethereumSepolia
    case hypersonicTestnet
    case lightlinkPegasus
    case modeSepolia
    case optimismGoerli
    case optimismSepolia
    case polygonMumbai
    case polygonAmoy
    case rariTestnet
    case scrollSepolia
    case seiAtlantic2Testnet
    case shapeSepolia
    case skaleNebulaTestnet
    case soneiumMinatoTestnet
    case spaceTestnet
    case storyTestnet
    case verifyTestnet
    case victionTestnet
    case xaiSepoliaTestnet
    case zkatana
    case zkyoto
    case zoraGoerli
    case zoraSepolia
    case zenchainTestnet

    case stellar
    case solana

    case unknown(name: String)

    private var specificChain: (any SpecificChain) {
        switch self {
        case .ethereum:
            EVMChain.ethereum
        case .polygon:
            EVMChain.polygon
        case .bsc:
            EVMChain.bsc
        case .optimism:
            EVMChain.optimism
        case .arbitrum:
            EVMChain.arbitrum
        case .base:
            EVMChain.base
        case .zora:
            EVMChain.zora
        case .arbitrumnova:
            EVMChain.arbitrumnova
        case .astarZkevm:
            EVMChain.astarZkevm
        case .apechain:
            EVMChain.apechain
        case .apex:
            EVMChain.apex
        case .boss:
            EVMChain.boss
        case .coti:
            EVMChain.coti
        case .lightlink:
            EVMChain.lightlink
        case .skaleNebula:
            EVMChain.skaleNebula
        case .seiPacific1:
            EVMChain.seiPacific1
        case .chiliz:
            EVMChain.chiliz
        case .avalanche:
            EVMChain.avalanche
        case .xai:
            EVMChain.xai
        case .shape:
            EVMChain.shape
        case .rari:
            EVMChain.rari
        case .scroll:
            EVMChain.scroll
        case .viction:
            EVMChain.viction
        case .mode:
            EVMChain.mode
        case .space:
            EVMChain.space
        case .soneium:
            EVMChain.soneium
        case .story:
            EVMChain.story
        case .arbitrumSepolia:
            EVMChain.arbitrumSepolia
        case .avalancheFuji:
            EVMChain.avalancheFuji
        case .curtis:
            EVMChain.curtis
        case .barretTestnet:
            EVMChain.barretTestnet
        case .baseGoerli:
            EVMChain.baseGoerli
        case .baseSepolia:
            EVMChain.baseSepolia
        case .bscTestnet:
            EVMChain.bscTestnet
        case .chilizSpicyTestnet:
            EVMChain.chilizSpicyTestnet
        case .cotiTestnet:
            EVMChain.cotiTestnet
        case .ethereumGoerli:
            EVMChain.ethereumGoerli
        case .ethereumSepolia:
            EVMChain.ethereumSepolia
        case .hypersonicTestnet:
            EVMChain.hypersonicTestnet
        case .lightlinkPegasus:
            EVMChain.lightlinkPegasus
        case .modeSepolia:
            EVMChain.modeSepolia
        case .optimismGoerli:
            EVMChain.optimismGoerli
        case .optimismSepolia:
            EVMChain.optimismSepolia
        case .polygonMumbai:
            EVMChain.polygonMumbai
        case .polygonAmoy:
            EVMChain.polygonAmoy
        case .rariTestnet:
            EVMChain.rariTestnet
        case .scrollSepolia:
            EVMChain.scrollSepolia
        case .seiAtlantic2Testnet:
            EVMChain.seiAtlantic2Testnet
        case .shapeSepolia:
            EVMChain.shapeSepolia
        case .skaleNebulaTestnet:
            EVMChain.skaleNebulaTestnet
        case .soneiumMinatoTestnet:
            EVMChain.soneiumMinatoTestnet
        case .spaceTestnet:
            EVMChain.spaceTestnet
        case .storyTestnet:
            EVMChain.storyTestnet
        case .verifyTestnet:
            EVMChain.verifyTestnet
        case .victionTestnet:
            EVMChain.victionTestnet
        case .xaiSepoliaTestnet:
            EVMChain.xaiSepoliaTestnet
        case .zkatana:
            EVMChain.zkatana
        case .zkyoto:
            EVMChain.zkyoto
        case .zoraGoerli:
            EVMChain.zoraGoerli
        case .zoraSepolia:
            EVMChain.zoraSepolia
        case .zenchainTestnet:
            EVMChain.zenchainTestnet
        case .stellar:
            StellarChain.stellar
        case .solana:
            SolanaChain.solana
        case .unknown(name: let name):
            UnknownChain.unknown(name: name, isTest: true)
        }
    }

    public var name: String {
        specificChain.name
    }

    public var chainType: ChainType {
        specificChain.chainType
    }

    public func isValid(isProductionEnvironment: Bool) -> Bool {
        specificChain.isValid(isProductionEnvironment: isProductionEnvironment)
    }
}
