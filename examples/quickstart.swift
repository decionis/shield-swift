import ShieldKit

let shield = ShieldClient() // sandbox by default; no key required
let decision = try await shield.authorize(
    amount: 89,
    currency: "USD",
    purpose: "Book hotel",
    merchant: "Hilton"
)

switch decision.verdict {
case .allowed:
    print("ALLOW — execute this exact action once")
case .approvalRequired:
    let approved = try await shield.requestApproval(decisionId: decision.decisionId)
    print("\(approved.verdict.rawValue) after approval")
case .blocked:
    print("BLOCK — cancel the transaction")
}
