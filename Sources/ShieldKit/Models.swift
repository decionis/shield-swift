import Foundation

public enum ShieldEnvironment: String, Codable, Sendable {
    case sandbox
    case production
}

public enum ShieldVerdict: String, Codable, Sendable {
    case allowed = "ALLOW"
    case approvalRequired = "ASK"
    case blocked = "BLOCK"
}

public enum ShieldTransactionType: String, Codable, Sendable {
    case purchase = "PURCHASE"
    case subscription = "SUBSCRIPTION"
    case renewal = "RENEWAL"
    case transfer = "TRANSFER"
    case refund = "REFUND"
    case other = "OTHER"
}

public enum ShieldApprovalStatus: String, Codable, Sendable {
    case notRequired = "NOT_REQUIRED"
    case pending = "PENDING"
    case approved = "APPROVED"
    case denied = "DENIED"
    case expired = "EXPIRED"
}

public enum JSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { self = .null }
        else if let decoded = try? value.decode(Bool.self) { self = .bool(decoded) }
        else if let decoded = try? value.decode(Double.self) { self = .number(decoded) }
        else if let decoded = try? value.decode(String.self) { self = .string(decoded) }
        else if let decoded = try? value.decode([String: JSONValue].self) { self = .object(decoded) }
        else { self = .array(try value.decode([JSONValue].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case let .string(decoded): try value.encode(decoded)
        case let .number(decoded): try value.encode(decoded)
        case let .bool(decoded): try value.encode(decoded)
        case let .object(decoded): try value.encode(decoded)
        case let .array(decoded): try value.encode(decoded)
        case .null: try value.encodeNil()
        }
    }
}

public struct ShieldIntegrationIdentity: Codable, Equatable, Sendable {
    public let appId: String
    public let displayName: String
    public let developer: String?
    public let iconUrl: String?

    public init(appId: String, displayName: String, developer: String? = nil, iconUrl: String? = nil) {
        self.appId = appId
        self.displayName = displayName
        self.developer = developer
        self.iconUrl = iconUrl
    }
}

public struct SpendingRequest: Codable, Equatable, Sendable {
    public let amount: Double
    public let currency: String
    public let purpose: String
    public let merchant: String?
    public let category: String?
    public let agentId: String?
    public let transactionType: ShieldTransactionType?
    public let metadata: [String: JSONValue]?

    public init(
        amount: Double,
        currency: String,
        purpose: String,
        merchant: String? = nil,
        category: String? = nil,
        agentId: String? = nil,
        transactionType: ShieldTransactionType? = nil,
        metadata: [String: JSONValue]? = nil
    ) {
        self.amount = amount
        self.currency = currency
        self.purpose = purpose
        self.merchant = merchant
        self.category = category
        self.agentId = agentId
        self.transactionType = transactionType
        self.metadata = metadata
    }
}

public struct ShieldDecisionAdvanced: Codable, Equatable, Sendable {
    public let policyVersion: String?
    public let reasonCodes: [String]?
    public let evidenceHash: String?
    public let evaluationMetadata: [String: JSONValue]?

    public init(
        policyVersion: String? = nil,
        reasonCodes: [String]? = nil,
        evidenceHash: String? = nil,
        evaluationMetadata: [String: JSONValue]? = nil
    ) {
        self.policyVersion = policyVersion
        self.reasonCodes = reasonCodes
        self.evidenceHash = evidenceHash
        self.evaluationMetadata = evaluationMetadata
    }
}

public struct ShieldDecision: Codable, Equatable, Sendable {
    public let verdict: ShieldVerdict
    public let allowed: Bool
    public let approvalRequired: Bool
    public let approvalStatus: ShieldApprovalStatus
    public let reason: String
    public let reasonCode: String
    public let requestId: String
    public let decisionId: String
    public let dossierId: String
    public let environment: ShieldEnvironment
    public let advanced: ShieldDecisionAdvanced?

    public init(
        verdict: ShieldVerdict,
        approvalStatus: ShieldApprovalStatus? = nil,
        reason: String,
        reasonCode: String,
        requestId: String,
        decisionId: String,
        dossierId: String,
        environment: ShieldEnvironment,
        advanced: ShieldDecisionAdvanced? = nil
    ) {
        self.verdict = verdict
        self.allowed = verdict == .allowed
        self.approvalRequired = verdict == .approvalRequired
        self.approvalStatus = approvalStatus ?? (verdict == .approvalRequired ? .pending : .notRequired)
        self.reason = reason
        self.reasonCode = reasonCode
        self.requestId = requestId
        self.decisionId = decisionId
        self.dossierId = dossierId
        self.environment = environment
        self.advanced = advanced
    }
}

public struct ShieldDossier: Codable, Equatable, Sendable {
    public let dossierId: String
    public let decisionId: String
    public let verdict: ShieldVerdict
    public let reasonCode: String
    public let environment: ShieldEnvironment
    public let evidenceClass: String
    public let evidenceHash: String?
    public let evaluation: [String: JSONValue]?
}

public enum ShieldSandboxScenario: String, CaseIterable, Sendable {
    case normalPurchase = "normal-purchase"
    case purchaseAboveLimit = "purchase-above-limit"
    case subscriptionBelowThreshold = "subscription-below-threshold"
    case subscriptionPriceIncrease = "subscription-price-increase"
    case unknownAutonomousAgent = "unknown-autonomous-agent"
    case agentWeeklyAllowanceExceeded = "agent-weekly-allowance-exceeded"
    case expiredSpendingPermission = "expired-spending-permission"
    case travelApproval = "travel-approval"
    case travelAllowanceExceeded = "travel-allowance-exceeded"
}
