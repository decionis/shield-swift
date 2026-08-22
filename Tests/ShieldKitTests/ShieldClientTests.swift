import XCTest
@testable import ShieldKit

final class ShieldClientTests: XCTestCase {
    func testSafeDefaultReturnsSandboxAllow() async throws {
        let shield = ShieldClient()
        let decision = try await shield.authorize(
            amount: 89,
            currency: "usd",
            purpose: "Book hotel",
            merchant: "Hilton"
        )
        XCTAssertEqual(decision.environment, .sandbox)
        XCTAssertEqual(decision.verdict, .allowed)
        XCTAssertTrue(decision.allowed)
        XCTAssertFalse(decision.approvalRequired)
        let dossier = try await shield.getDossier(decision.dossierId)
        XCTAssertEqual(dossier.evidenceClass, "sandbox_fixture")
    }

    func testEveryNamedScenarioReturnsExpectedVerdict() async throws {
        let expected: [ShieldSandboxScenario: ShieldVerdict] = [
            .normalPurchase: .allowed,
            .purchaseAboveLimit: .approvalRequired,
            .subscriptionBelowThreshold: .allowed,
            .subscriptionPriceIncrease: .approvalRequired,
            .unknownAutonomousAgent: .blocked,
            .agentWeeklyAllowanceExceeded: .blocked,
            .expiredSpendingPermission: .blocked,
            .travelApproval: .approvalRequired,
            .travelAllowanceExceeded: .blocked,
        ]
        for scenario in ShieldSandboxScenario.allCases {
            let decision = try await ShieldClient().authorize(
                amount: 267,
                currency: "EUR",
                purpose: "Run sandbox scenario",
                sandboxScenario: scenario
            )
            XCTAssertEqual(decision.verdict, expected[scenario], scenario.rawValue)
        }
    }

    func testAskRequiresExplicitApproval() async throws {
        let shield = ShieldClient()
        let held = try await shield.authorize(
            amount: 267,
            currency: "EUR",
            purpose: "Book hotel",
            sandboxScenario: .travelApproval
        )
        XCTAssertEqual(held.verdict, .approvalRequired)
        XCTAssertFalse(held.allowed)
        let approved = try await shield.requestApproval(decisionId: held.decisionId)
        XCTAssertEqual(approved.verdict, .allowed)
        XCTAssertEqual(approved.approvalStatus, .approved)
    }

    func testInvalidRequestFailsClosedWithAction() async {
        do {
            _ = try await ShieldClient().authorize(amount: 0, currency: "USD", purpose: "Buy")
            XCTFail("Expected validation error")
        } catch let error as ShieldError {
            XCTAssertEqual(error.code, .invalidRequest)
            XCTAssertFalse(error.safeToExecute)
            XCTAssertTrue(error.description.contains("Do not execute the transaction"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
