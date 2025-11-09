import CrossmintCommonTypes

public protocol BaseLineItem: Codable, Sendable {
    var chain: Chain { get set }
    var callData: CallData? { get set }
    var executionParams: ExecutionParameters? { get set }
    var metadata: MetadataWithOptionalCollection { get set }
    var quote: LineItemQuote { get set }
    var delivery: LineItemDelivery { get set }
}

public struct ExactOutLineItem: BaseLineItem {
    public var callData: CallData?
    public var executionParams: ExecutionParameters?
    public var metadata: MetadataWithOptionalCollection
    public var chain: CrossmintCommonTypes.Chain
    public var quote: LineItemQuote
    public var delivery: LineItemDelivery

    public private(set) var executionMode: ExecutionMode = .exactOut
    public private(set) var quantity: Int

    public init(
        callData: CallData? = nil,
        executionParams: ExecutionParameters? = nil,
        metadata: MetadataWithOptionalCollection,
        chain: Chain,
        quote: LineItemQuote,
        delivery: LineItemDelivery,
        quantity: Int
    ) throws(PaymentError) {
        guard quantity > 0 else {
            throw PaymentError.quantityMustBeGreaterThanZero
        }

        self.callData = callData
        self.executionParams = executionParams
        self.metadata = metadata
        self.chain = chain
        self.quote = quote
        self.delivery = delivery
        self.quantity = quantity
    }

    public init(from decoder: Decoder) throws(PaymentError) {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            // Decode all other properties
            self.callData = try container.decodeIfPresent(CallData.self, forKey: .callData)
            self.executionParams = try container.decodeIfPresent(
                ExecutionParameters.self, forKey: .executionParams)
            self.metadata = try container.decode(
                MetadataWithOptionalCollection.self, forKey: .metadata)
            self.chain = try container.decode(Chain.self, forKey: .chain)
            self.quote = try container.decode(LineItemQuote.self, forKey: .quote)
            self.delivery = try container.decode(LineItemDelivery.self, forKey: .delivery)

            // Decode and validate quantity
            let quantity = try container.decode(Int.self, forKey: .quantity)
            guard quantity > 0 else {
                throw PaymentError.quantityMustBeGreaterThanZero
            }
            self.quantity = quantity

            // Validate executionMode if present
            if let mode = try container.decodeIfPresent(ExecutionMode.self, forKey: .executionMode) {
                guard mode == .exactOut else {
                    throw PaymentError.invalidExecutionMode(
                        expected: "exact-out", got: String(describing: mode))
                }
            }
            // executionMode is already set to .exactOut by default
        } catch let error as PaymentError {
            throw error
        } catch {
            throw PaymentError.decodingError(error)
        }
    }
}

public struct ExactInLineItem: BaseLineItem {
    public var chain: CrossmintCommonTypes.Chain
    public var callData: CallData?
    public var executionParams: ExecutionParameters?
    public var metadata: MetadataWithOptionalCollection
    public var quote: LineItemQuote
    public var delivery: LineItemDelivery

    public private(set) var executionMode: ExecutionMode = .exactIn
    public var maxSlippageBps: String

    public init(from decoder: Decoder) throws(PaymentError) {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            // Decode all other properties
            self.chain = try container.decode(Chain.self, forKey: .chain)
            self.callData = try container.decodeIfPresent(CallData.self, forKey: .callData)
            self.executionParams = try container.decodeIfPresent(
                ExecutionParameters.self, forKey: .executionParams)
            self.metadata = try container.decode(
                MetadataWithOptionalCollection.self, forKey: .metadata)
            self.quote = try container.decode(LineItemQuote.self, forKey: .quote)
            self.delivery = try container.decode(LineItemDelivery.self, forKey: .delivery)
            self.maxSlippageBps = try container.decode(String.self, forKey: .maxSlippageBps)

            // Validate executionMode if present
            if let mode = try container.decodeIfPresent(ExecutionMode.self, forKey: .executionMode) {
                guard mode == .exactIn else {
                    throw PaymentError.invalidExecutionMode(
                        expected: "exact-in", got: String(describing: mode))
                }
            }
            // executionMode is already set to .exactIn by default
        } catch let error as PaymentError {
            throw error
        } catch {
            throw PaymentError.decodingError(error)
        }
    }
}

public enum LineItem: Codable, Sendable, Identifiable {
    public var id: String {
        // The id is the json of the line item
        let id = self.json()
        return id
    }

    case exactOut(ExactOutLineItem)
    case exactIn(ExactInLineItem)

    var isUnavailable: Bool {
        switch self {
        case .exactOut(let item):
            return item.quote.isUnavailable
        case .exactIn(let item):
            return item.quote.isUnavailable
        }
    }

    var unavailabilityReason: LineItemQuoteUnavailabilityReason? {
        switch self {
        case .exactOut(let item):
            return item.quote.unavailabilityReason
        case .exactIn(let item):
            return item.quote.unavailabilityReason
        }
    }

    // Custom Codable implementation to handle LineItem without a top-level key
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // Try to decode as ExactOutLineItem first
        do {
            let exactOutItem = try container.decode(ExactOutLineItem.self)
            self = .exactOut(exactOutItem)
            return
        } catch {
            // If that fails, try ExactInLineItem
            do {
                let exactInItem = try container.decode(ExactInLineItem.self)
                self = .exactIn(exactInItem)
                return
            } catch {
                // If both fail, determine which one to use based on executionMode
                let container = try decoder.container(keyedBy: CodingKeys.self)
                if let executionMode = try container.decodeIfPresent(
                    String.self, forKey: .executionMode) {
                    if executionMode == "exact-out" {
                        let exactOutItem = try ExactOutLineItem(from: decoder)
                        self = .exactOut(exactOutItem)
                    } else if executionMode == "exact-in" {
                        let exactInItem = try ExactInLineItem(from: decoder)
                        self = .exactIn(exactInItem)
                    } else {
                        throw DecodingError.dataCorruptedError(
                            forKey: .executionMode,
                            in: container,
                            debugDescription: "Invalid execution mode: \(executionMode)"
                        )
                    }
                } else {
                    // Default to exactOut if no executionMode is provided
                    let exactOutItem = try ExactOutLineItem(from: decoder)
                    self = .exactOut(exactOutItem)
                }
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .exactOut(let exactOutItem):
            try exactOutItem.encode(to: encoder)
        case .exactIn(let exactInItem):
            try exactInItem.encode(to: encoder)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case executionMode
    }

    public var exactOut: ExactOutLineItem? {
        if case .exactOut(let item) = self {
            return item
        }

        return nil
    }

    public var exactIn: ExactInLineItem? {
        if case .exactIn(let item) = self {
            return item
        }

        return nil
    }

    public var quote: LineItemQuote {
        switch self {
        case .exactOut(let item):
            return item.quote
        case .exactIn(let item):
            return item.quote
        }
    }

    public var delivery: LineItemDelivery {
        switch self {
        case .exactOut(let item):
            return item.delivery
        case .exactIn(let item):
            return item.delivery
        }
    }

    public var chain: Chain {
        switch self {
        case .exactOut(let item):
            return item.chain
        case .exactIn(let item):
            return item.chain
        }
    }

    public var metadata: MetadataWithOptionalCollection {
        switch self {
        case .exactOut(let item):
            return item.metadata
        case .exactIn(let item):
            return item.metadata
        }
    }
}
