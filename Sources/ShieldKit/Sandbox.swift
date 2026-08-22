import Foundation

struct SandboxFixture: Sendable {
    let scenario: ShieldSandboxScenario
    let permission: String
    let verdict: ShieldVerdict
    let reason: String
    let reasonCode: String
}

enum ShieldSandbox {
    static func evaluate(
        request: SpendingRequest,
        scenario: ShieldSandboxScenario?
    ) throws -> (ShieldDecision, ShieldDossier) {
        let fixture = fixture(for: request, scenario: scenario)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let digest = stableHash(try encoder.encode(request))
        let requestId = "shr_sbx_\(digest)"
        let decisionId = "dec_sbx_\(digest)"
        let dossierId = "dsr_sbx_\(digest)"
        let advanced = ShieldDecisionAdvanced(
            policyVersion: "shield-sandbox-v1",
            reasonCodes: [fixture.reasonCode],
            evidenceHash: "sandbox:\(digest)",
            evaluationMetadata: [
                "scenario": .string(fixture.scenario.rawValue),
                "permission": .string(fixture.permission),
                "evidenceClass": .string("sandbox_fixture"),
            ]
        )
        let decision = ShieldDecision(
            verdict: fixture.verdict,
            reason: fixture.reason,
            reasonCode: fixture.reasonCode,
            requestId: requestId,
            decisionId: decisionId,
            dossierId: dossierId,
            environment: .sandbox,
            advanced: advanced
        )
        let dossier = ShieldDossier(
            dossierId: dossierId,
            decisionId: decisionId,
            verdict: fixture.verdict,
            reasonCode: fixture.reasonCode,
            environment: .sandbox,
            evidenceClass: "sandbox_fixture",
            evidenceHash: "sandbox:\(digest)",
            evaluation: [
                "scenario": .string(fixture.scenario.rawValue),
                "permission": .string(fixture.permission),
            ]
        )
        return (decision, dossier)
    }

    private static func fixture(
        for request: SpendingRequest,
        scenario: ShieldSandboxScenario?
    ) -> SandboxFixture {
        let selected: ShieldSandboxScenario
        if let scenario { selected = scenario }
        else if request.agentId == "unknown-agent" { selected = .unknownAutonomousAgent }
        else if request.metadata?["permissionExpired"] == .bool(true) { selected = .expiredSpendingPermission }
        else if case let .number(previous)? = request.metadata?["previousAmount"], request.amount > previous {
            selected = .subscriptionPriceIncrease
        } else if request.amount > 500 { selected = .travelAllowanceExceeded }
        else if request.amount > 100 { selected = .purchaseAboveLimit }
        else if request.transactionType == .subscription || request.transactionType == .renewal {
            selected = .subscriptionBelowThreshold
        } else { selected = .normalPurchase }

        switch selected {
        case .normalPurchase:
            return .init(scenario: selected, permission: "Automatic purchases up to $100", verdict: .allowed, reason: "This purchase is within the user's automatic spending authority.", reasonCode: "WITHIN_SPENDING_AUTHORITY")
        case .purchaseAboveLimit:
            return .init(scenario: selected, permission: "Automatic purchases up to $100; ask up to $500", verdict: .approvalRequired, reason: "This purchase exceeds the user's automatic spending limit.", reasonCode: "USER_THRESHOLD_EXCEEDED")
        case .subscriptionBelowThreshold:
            return .init(scenario: selected, permission: "Subscription renewals up to $25", verdict: .allowed, reason: "This renewal is within the user's subscription permission.", reasonCode: "WITHIN_SUBSCRIPTION_AUTHORITY")
        case .subscriptionPriceIncrease:
            return .init(scenario: selected, permission: "Ask when a subscription price increases", verdict: .approvalRequired, reason: "The renewal price is higher than the amount the user previously authorized.", reasonCode: "SUBSCRIPTION_PRICE_INCREASED")
        case .unknownAutonomousAgent:
            return .init(scenario: selected, permission: "Only recognized apps and agents may spend", verdict: .blocked, reason: "The requesting autonomous agent is not known to the user's Shield.", reasonCode: "UNKNOWN_SPENDER_IDENTITY")
        case .agentWeeklyAllowanceExceeded:
            return .init(scenario: selected, permission: "Travel Agent weekly allowance €500", verdict: .blocked, reason: "This purchase would exceed the agent's weekly spending allowance.", reasonCode: "AGENT_ALLOWANCE_EXCEEDED")
        case .expiredSpendingPermission:
            return .init(scenario: selected, permission: "Project Agent permission expired", verdict: .blocked, reason: "The spending permission expired before this request was evaluated.", reasonCode: "SPENDING_PERMISSION_EXPIRED")
        case .travelApproval:
            return .init(scenario: selected, permission: "Travel purchases above €200 require approval", verdict: .approvalRequired, reason: "Travel purchases above €200 require user approval.", reasonCode: "USER_THRESHOLD_EXCEEDED")
        case .travelAllowanceExceeded:
            return .init(scenario: selected, permission: "Travel allowance €500", verdict: .blocked, reason: "Spending authority exceeded.", reasonCode: "SPENDING_AUTHORITY_EXCEEDED")
        }
    }

    private static func stableHash(_ data: Data) -> String {
        var hash: UInt32 = 0x811c9dc5
        for byte in data {
            hash ^= UInt32(byte)
            hash = hash &* 0x01000193
        }
        return String(format: "%08x", hash)
    }
}
