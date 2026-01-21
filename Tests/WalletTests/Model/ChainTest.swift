import CrossmintCommonTypes
import Foundation
import Testing

@testable import Wallet

struct ChainTest {
    @Test(
        "Will set unknown chain if the name is not known"
    )
    func willParseUnknownChains() async {
        let chain = getChain(
            """
            {
                    "chain": "new_type_of_chain",
            }
            """
        )

        #expect(chain == .unknown(name: "new_type_of_chain"))
    }

    @Test(
        "Will use the expected type when the name is known"
    )
    func willParseKnownChains() async {
        let chain = getChain(
            """
            {
                    "chain": "ethereum",
            }
            """
        )

        #expect(chain == .ethereum)
    }

    @Test(
        "Will parse solana chain"
    )
    func willParseSolanaChain() async {
        let chain = getChain(
            """
            {
                    "chain": "solana",
            }
            """
        )

        #expect(chain == .solana)
    }

    @Test(
        "Production chains should be valid in production environment"
    )
    func productionChainsValidInProduction() async {
        let productionChains: [Chain] = [
            .ethereum,
            .polygon,
            .bsc,
            .optimism,
            .arbitrum,
            .base,
            .zora,
            .solana
        ]

        for chain in productionChains {
            #expect(
                chain.isValid(isProductionEnvironment: true),
                "Chain \(chain.name) should be valid in production environment"
            )
        }
    }

    @Test(
        "Production chains should be invalid in test environment"
    )
    func productionChainsInvalidInTest() async {
        let productionChains: [Chain] = [
            .ethereum,
            .polygon,
            .bsc,
            .optimism,
            .arbitrum,
            .base,
            .zora
        ]

        for chain in productionChains {
            #expect(
                !chain.isValid(isProductionEnvironment: false),
                "Chain \(chain.name) should be invalid in test environment"
            )
        }
    }

    @Test(
        "Test chains should be valid in test environment"
    )
    func testChainsValidInTest() async {
        let testChains: [Chain] = [
            .ethereumSepolia,
            .polygonMumbai,
            .polygonAmoy,
            .bscTestnet,
            .optimismSepolia,
            .arbitrumSepolia,
            .baseSepolia,
            .zoraSepolia
        ]

        for chain in testChains {
            #expect(
                chain.isValid(isProductionEnvironment: false),
                "Chain \(chain.name) should be valid in test environment"
            )
        }
    }

    @Test(
        "Test chains should be invalid in production environment"
    )
    func testChainsInvalidInProduction() async {
        let testChains: [Chain] = [
            .ethereumSepolia,
            .polygonMumbai,
            .polygonAmoy,
            .bscTestnet,
            .optimismSepolia,
            .arbitrumSepolia,
            .baseSepolia,
            .zoraSepolia
        ]

        for chain in testChains {
            #expect(
                !chain.isValid(isProductionEnvironment: true),
                "Chain \(chain.name) should be invalid in production environment"
            )
        }
    }

    @Test(
        "Solana chain should be valid in both environments"
    )
    func solanaValidInBothEnvironments() async {
        let solanaChain = Chain.solana

        #expect(
            solanaChain.isValid(isProductionEnvironment: true),
            "Solana should be valid in production environment"
        )
        #expect(
            solanaChain.isValid(isProductionEnvironment: false),
            "Solana should be valid in test environment"
        )
    }

    @Test(
        "Unknown chains should be valid in both environments"
    )
    func unknownChainsValidInBothEnvironments() async {
        let unknownChain = Chain.unknown(name: "custom_chain")

        #expect(
            unknownChain.isValid(isProductionEnvironment: true),
            "Unknown chain should be valid in production environment"
        )
    }

    @Test(
        "Chain should equal corresponding EVMChain"
    )
    func chainEqualsCorrespondingEvmChain() async {
        // Test Chain.ethereum == EVMChain.ethereum
        #expect(Chain.ethereum == EVMChain.ethereum, "Chain.ethereum should equal EVMChain.ethereum")
        #expect(EVMChain.ethereum == Chain.ethereum, "EVMChain.ethereum should equal Chain.ethereum")

        // Test several other major chains
        #expect(Chain.polygon == EVMChain.polygon, "Chain.polygon should equal EVMChain.polygon")
        #expect(EVMChain.polygon == Chain.polygon, "EVMChain.polygon should equal Chain.polygon")

        #expect(Chain.arbitrum == EVMChain.arbitrum, "Chain.arbitrum should equal EVMChain.arbitrum")
        #expect(EVMChain.arbitrum == Chain.arbitrum, "EVMChain.arbitrum should equal Chain.arbitrum")

        #expect(Chain.base == EVMChain.base, "Chain.base should equal EVMChain.base")
        #expect(EVMChain.base == Chain.base, "EVMChain.base should equal Chain.base")
    }

    @Test(
        "Chain should equal corresponding SolanaChain"
    )
    func chainEqualsCorrespondingSolanaChain() async {
        #expect(Chain.solana == SolanaChain.solana, "Chain.solana should equal SolanaChain.solana")
        #expect(SolanaChain.solana == Chain.solana, "SolanaChain.solana should equal Chain.solana")
    }

    @Test(
        "Chain should not equal non-corresponding specific chains"
    )
    func chainDoesNotEqualNonCorrespondingChains() async {
        // Chain.ethereum should not equal other EVMChains
        #expect(Chain.ethereum != EVMChain.polygon, "Chain.ethereum should not equal EVMChain.polygon")
        #expect(EVMChain.polygon != Chain.ethereum, "EVMChain.polygon should not equal Chain.ethereum")

        // Chain.solana should not equal any EVMChain
        #expect(Chain.solana != EVMChain.ethereum, "Chain.solana should not equal EVMChain.ethereum")
        #expect(EVMChain.ethereum != Chain.solana, "EVMChain.ethereum should not equal Chain.solana")

        // Chain.ethereum should not equal SolanaChain
        #expect(Chain.ethereum != SolanaChain.solana, "Chain.ethereum should not equal SolanaChain.solana")
        #expect(SolanaChain.solana != Chain.ethereum, "SolanaChain.solana should not equal Chain.ethereum")
    }

    @Test(
        "Unknown chains should not equal any specific chain type"
    )
    func unknownChainsDoNotEqualSpecificChains() async {
        let unknownChain = Chain.unknown(name: "custom_chain")

        #expect(unknownChain != EVMChain.ethereum, "Unknown chain should not equal EVMChain.ethereum")
        #expect(EVMChain.ethereum != unknownChain, "EVMChain.ethereum should not equal unknown chain")

        #expect(unknownChain != SolanaChain.solana, "Unknown chain should not equal SolanaChain.solana")
        #expect(SolanaChain.solana != unknownChain, "SolanaChain.solana should not equal unknown chain")
    }

    @Test(
        "Test chains should equal corresponding EVMChain test variants"
    )
    func testChainsEqualCorrespondingEvmTestChains() async {
        #expect(
            Chain.ethereumSepolia == EVMChain.ethereumSepolia,
            "Chain.ethereumSepolia should equal EVMChain.ethereumSepolia"
        )
        #expect(
            EVMChain.ethereumSepolia == Chain.ethereumSepolia,
            "EVMChain.ethereumSepolia should equal Chain.ethereumSepolia"
        )

        #expect(Chain.polygonAmoy == EVMChain.polygonAmoy, "Chain.polygonAmoy should equal EVMChain.polygonAmoy")
        #expect(EVMChain.polygonAmoy == Chain.polygonAmoy, "EVMChain.polygonAmoy should equal Chain.polygonAmoy")

        #expect(Chain.baseSepolia == EVMChain.baseSepolia, "Chain.baseSepolia should equal EVMChain.baseSepolia")
        #expect(EVMChain.baseSepolia == Chain.baseSepolia, "EVMChain.baseSepolia should equal Chain.baseSepolia")
    }

    @Test(
        "Comprehensive EVM chain comparison test"
    )
    func comprehensiveEvmChainComparison() async {
        let evmChainPairs: [(Chain, EVMChain)] = [
            (.ethereum, .ethereum),
            (.polygon, .polygon),
            (.bsc, .bsc),
            (.optimism, .optimism),
            (.arbitrum, .arbitrum),
            (.base, .base),
            (.zora, .zora),
            (.avalanche, .avalanche),
            (.scroll, .scroll),
            (.ethereumSepolia, .ethereumSepolia),
            (.polygonAmoy, .polygonAmoy),
            (.bscTestnet, .bscTestnet),
            (.optimismSepolia, .optimismSepolia),
            (.arbitrumSepolia, .arbitrumSepolia),
            (.baseSepolia, .baseSepolia),
            (.zoraSepolia, .zoraSepolia),
            (.avalancheFuji, .avalancheFuji),
            (.scrollSepolia, .scrollSepolia)
        ]

        for (chainEnum, evmChain) in evmChainPairs {
            #expect(
                chainEnum == evmChain,
                "Chain.\(chainEnum) should equal EVMChain.\(evmChain)"
            )
            #expect(
                evmChain == chainEnum,
                "EVMChain.\(evmChain) should equal Chain.\(chainEnum)"
            )
        }
    }

    private func getChain(_ json: String) -> Chain? {
        struct ChainResponse: Decodable {
            let chain: Chain
        }

        guard let data = json.data(using: .utf8),
              let chainResponse: ChainResponse = try? JSONDecoder().decode(
                ChainResponse.self, from: data
              ) else { return nil }
        return chainResponse.chain
    }
}
