public enum EVMChain: SpecificChain, CaseIterable, Equatable {
    public init?(_ from: String) {
        guard let knownChain = Known(rawValue: from) else { return nil }
        self = knownChain.chain
    }

    private enum Known: String {
        case ethereum
        case polygon
        case bsc
        case optimism
        case arbitrum
        case base
        case zora
        case arbitrumnova
        case astarZkevm = "astar-zkevm"
        case apechain
        case apex
        case boss
        case coti
        case lightlink
        case skaleNebula = "skale-nebula"
        case seiPacific1 = "sei-pacific-1"
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
        case arbitrumSepolia = "arbitrum-sepolia"
        case avalancheFuji = "avalanche-fuji"
        case curtis = "curtis"
        case barretTestnet = "barret-testnet"
        case baseGoerli = "base-goerli"
        case baseSepolia = "base-sepolia"
        case bscTestnet = "bsc-testnet"
        case chilizSpicyTestnet = "chiliz-spicy-testnet"
        case cotiTestnet = "coti-testnet"
        case ethereumGoerli = "ethereum-goerli"
        case ethereumSepolia = "ethereum-sepolia"
        case hypersonicTestnet = "hypersonic-testnet"
        case lightlinkPegasus = "lightlink-pegasus"
        case modeSepolia = "mode-sepolia"
        case optimismGoerli = "optimism-goerli"
        case optimismSepolia = "optimism-sepolia"
        case polygonMumbai = "polygon-mumbai"
        case polygonAmoy = "polygon-amoy"
        case rariTestnet = "rari-testnet"
        case scrollSepolia = "scroll-sepolia"
        case seiAtlantic2Testnet = "sei-atlantic-2-testnet"
        case shapeSepolia = "shape-sepolia"
        case skaleNebulaTestnet = "skale-nebula-testnet"
        case soneiumMinatoTestnet = "soneium-minato-testnet"
        case spaceTestnet = "space-testnet"
        case storyTestnet = "story-testnet"
        case verifyTestnet = "verify-testnet"
        case victionTestnet = "viction-testnet"
        case xaiSepoliaTestnet = "xai-sepolia-testnet"
        case zkatana = "zkatana"
        case zkyoto = "zkyoto"
        case zoraGoerli = "zora-goerli"
        case zoraSepolia = "zora-sepolia"
        case zenchainTestnet = "zenchain-testnet"

        var chain: EVMChain {
            switch self {
            case .ethereum: .ethereum
            case .polygon: .polygon
            case .bsc: .bsc
            case .optimism: .optimism
            case .arbitrum: .arbitrum
            case .base: .base
            case .zora: .zora
            case .arbitrumnova: .arbitrumnova
            case .astarZkevm: .astarZkevm
            case .apechain: .apechain
            case .apex: .apex
            case .boss: .boss
            case .coti: .coti
            case .lightlink: .lightlink
            case .skaleNebula: .skaleNebula
            case .seiPacific1: .seiPacific1
            case .chiliz: .chiliz
            case .avalanche: .avalanche
            case .xai: .xai
            case .shape: .shape
            case .rari: .rari
            case .scroll: .scroll
            case .viction: .viction
            case .mode: .mode
            case .space: .space
            case .soneium: .soneium
            case .story: .story
            case .arbitrumSepolia: .arbitrumSepolia
            case .avalancheFuji: .avalancheFuji
            case .curtis: .curtis
            case .barretTestnet: .barretTestnet
            case .baseGoerli: .baseGoerli
            case .baseSepolia: .baseSepolia
            case .bscTestnet: .bscTestnet
            case .chilizSpicyTestnet: .chilizSpicyTestnet
            case .cotiTestnet: .cotiTestnet
            case .ethereumGoerli: .ethereumGoerli
            case .ethereumSepolia: .ethereumSepolia
            case .hypersonicTestnet: .hypersonicTestnet
            case .lightlinkPegasus: .lightlinkPegasus
            case .modeSepolia: .modeSepolia
            case .optimismGoerli: .optimismGoerli
            case .optimismSepolia: .optimismSepolia
            case .polygonMumbai: .polygonMumbai
            case .polygonAmoy: .polygonAmoy
            case .rariTestnet: .rariTestnet
            case .scrollSepolia: .scrollSepolia
            case .seiAtlantic2Testnet: .seiAtlantic2Testnet
            case .shapeSepolia: .shapeSepolia
            case .skaleNebulaTestnet: .skaleNebulaTestnet
            case .soneiumMinatoTestnet: .soneiumMinatoTestnet
            case .spaceTestnet: .spaceTestnet
            case .storyTestnet: .storyTestnet
            case .verifyTestnet: .verifyTestnet
            case .victionTestnet: .victionTestnet
            case .xaiSepoliaTestnet: .xaiSepoliaTestnet
            case .zkatana: .zkatana
            case .zkyoto: .zkyoto
            case .zoraGoerli: .zoraGoerli
            case .zoraSepolia: .zoraSepolia
            case .zenchainTestnet: .zenchainTestnet
            }
        }
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

    public var chainType: ChainType {
        .evm
    }

    public var chain: Chain {
        switch self {
        case .ethereum: .ethereum
        case .polygon: .polygon
        case .bsc: .bsc
        case .optimism: .optimism
        case .arbitrum: .arbitrum
        case .base: .base
        case .zora: .zora
        case .arbitrumnova: .arbitrumnova
        case .astarZkevm: .astarZkevm
        case .apechain: .apechain
        case .apex: .apex
        case .boss: .boss
        case .coti: .coti
        case .lightlink: .lightlink
        case .skaleNebula: .skaleNebula
        case .seiPacific1: .seiPacific1
        case .chiliz: .chiliz
        case .avalanche: .avalanche
        case .xai: .xai
        case .shape: .shape
        case .rari: .rari
        case .scroll: .scroll
        case .viction: .viction
        case .mode: .mode
        case .space: .space
        case .soneium: .soneium
        case .story: .story
        case .arbitrumSepolia: .arbitrumSepolia
        case .avalancheFuji: .avalancheFuji
        case .curtis: .curtis
        case .barretTestnet: .barretTestnet
        case .baseGoerli: .baseGoerli
        case .baseSepolia: .baseSepolia
        case .bscTestnet: .bscTestnet
        case .chilizSpicyTestnet: .chilizSpicyTestnet
        case .cotiTestnet: .cotiTestnet
        case .ethereumGoerli: .ethereumGoerli
        case .ethereumSepolia: .ethereumSepolia
        case .hypersonicTestnet: .hypersonicTestnet
        case .lightlinkPegasus: .lightlinkPegasus
        case .modeSepolia: .modeSepolia
        case .optimismGoerli: .optimismGoerli
        case .optimismSepolia: .optimismSepolia
        case .polygonMumbai: .polygonMumbai
        case .polygonAmoy: .polygonAmoy
        case .rariTestnet: .rariTestnet
        case .scrollSepolia: .scrollSepolia
        case .seiAtlantic2Testnet: .seiAtlantic2Testnet
        case .shapeSepolia: .shapeSepolia
        case .skaleNebulaTestnet: .skaleNebulaTestnet
        case .soneiumMinatoTestnet: .soneiumMinatoTestnet
        case .spaceTestnet: .spaceTestnet
        case .storyTestnet: .storyTestnet
        case .verifyTestnet: .verifyTestnet
        case .victionTestnet: .victionTestnet
        case .xaiSepoliaTestnet: .xaiSepoliaTestnet
        case .zkatana: .zkatana
        case .zkyoto: .zkyoto
        case .zoraGoerli: .zoraGoerli
        case .zoraSepolia: .zoraSepolia
        case .zenchainTestnet: .zenchainTestnet
        }
    }

    public func isValid(isProductionEnvironment: Bool) -> Bool {
        isProductionEnvironment ? !isTest : isTest
    }

    public var name: String {
        switch self {
        case .ethereum: Known.ethereum.rawValue
        case .polygon: Known.polygon.rawValue
        case .bsc: Known.bsc.rawValue
        case .optimism: Known.optimism.rawValue
        case .arbitrum: Known.arbitrum.rawValue
        case .base: Known.base.rawValue
        case .zora: Known.zora.rawValue
        case .arbitrumnova: Known.arbitrumnova.rawValue
        case .astarZkevm: Known.astarZkevm.rawValue
        case .apechain: Known.apechain.rawValue
        case .apex: Known.apex.rawValue
        case .boss: Known.boss.rawValue
        case .coti: Known.coti.rawValue
        case .lightlink: Known.lightlink.rawValue
        case .skaleNebula: Known.skaleNebula.rawValue
        case .seiPacific1: Known.seiPacific1.rawValue
        case .chiliz: Known.chiliz.rawValue
        case .avalanche: Known.avalanche.rawValue
        case .xai: Known.xai.rawValue
        case .shape: Known.shape.rawValue
        case .rari: Known.rari.rawValue
        case .scroll: Known.scroll.rawValue
        case .viction: Known.viction.rawValue
        case .mode: Known.mode.rawValue
        case .space: Known.space.rawValue
        case .soneium: Known.soneium.rawValue
        case .story: Known.story.rawValue
        case .arbitrumSepolia: Known.arbitrumSepolia.rawValue
        case .avalancheFuji: Known.avalancheFuji.rawValue
        case .curtis: Known.curtis.rawValue
        case .barretTestnet: Known.barretTestnet.rawValue
        case .baseGoerli: Known.baseGoerli.rawValue
        case .baseSepolia: Known.baseSepolia.rawValue
        case .bscTestnet: Known.bscTestnet.rawValue
        case .chilizSpicyTestnet: Known.chilizSpicyTestnet.rawValue
        case .cotiTestnet: Known.cotiTestnet.rawValue
        case .ethereumGoerli: Known.ethereumGoerli.rawValue
        case .ethereumSepolia: Known.ethereumSepolia.rawValue
        case .hypersonicTestnet: Known.hypersonicTestnet.rawValue
        case .lightlinkPegasus: Known.lightlinkPegasus.rawValue
        case .modeSepolia: Known.modeSepolia.rawValue
        case .optimismGoerli: Known.optimismGoerli.rawValue
        case .optimismSepolia: Known.optimismSepolia.rawValue
        case .polygonMumbai: Known.polygonMumbai.rawValue
        case .polygonAmoy: Known.polygonAmoy.rawValue
        case .rariTestnet: Known.rariTestnet.rawValue
        case .scrollSepolia: Known.scrollSepolia.rawValue
        case .seiAtlantic2Testnet: Known.seiAtlantic2Testnet.rawValue
        case .shapeSepolia: Known.shapeSepolia.rawValue
        case .skaleNebulaTestnet: Known.skaleNebulaTestnet.rawValue
        case .soneiumMinatoTestnet: Known.soneiumMinatoTestnet.rawValue
        case .spaceTestnet: Known.spaceTestnet.rawValue
        case .storyTestnet: Known.storyTestnet.rawValue
        case .verifyTestnet: Known.verifyTestnet.rawValue
        case .victionTestnet: Known.victionTestnet.rawValue
        case .xaiSepoliaTestnet: Known.xaiSepoliaTestnet.rawValue
        case .zkatana: Known.zkatana.rawValue
        case .zkyoto: Known.zkyoto.rawValue
        case .zoraGoerli: Known.zoraGoerli.rawValue
        case .zoraSepolia: Known.zoraSepolia.rawValue
        case .zenchainTestnet: Known.zenchainTestnet.rawValue
        }
    }

    private var isTest: Bool {
        switch self {
        case .ethereum,
                .polygon,
                .bsc,
                .optimism,
                .arbitrum,
                .base,
                .zora,
                .arbitrumnova,
                .astarZkevm,
                .apechain,
                .apex,
                .boss,
                .coti,
                .lightlink,
                .skaleNebula,
                .seiPacific1,
                .chiliz,
                .avalanche,
                .xai,
                .shape,
                .rari,
                .scroll,
                .viction,
                .mode,
                .space,
                .soneium,
                .story:
            false
        case .arbitrumSepolia,
                .avalancheFuji,
                .curtis,
                .barretTestnet,
                .baseGoerli,
                .baseSepolia,
                .bscTestnet,
                .chilizSpicyTestnet,
                .cotiTestnet,
                .ethereumGoerli,
                .ethereumSepolia,
                .hypersonicTestnet,
                .lightlinkPegasus,
                .modeSepolia,
                .optimismGoerli,
                .optimismSepolia,
                .polygonMumbai,
                .polygonAmoy,
                .rariTestnet,
                .scrollSepolia,
                .seiAtlantic2Testnet,
                .shapeSepolia,
                .skaleNebulaTestnet,
                .soneiumMinatoTestnet,
                .spaceTestnet,
                .storyTestnet,
                .verifyTestnet,
                .victionTestnet,
                .xaiSepoliaTestnet,
                .zkatana,
                .zkyoto,
                .zoraGoerli,
                .zoraSepolia,
                .zenchainTestnet:
            true
        }
    }
}
