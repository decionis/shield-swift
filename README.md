# Consumer Spending Authorization for Swift

**ShieldKit** — let an iOS or macOS app ask the user's Shield before spending their money.

## Requirements

- iOS 15+
- macOS 12+
- Swift 5.9+

## Install

In Xcode, choose **File → Add Package Dependencies…** and add the ShieldKit package URL:

```swift
dependencies: [
    .package(url: "https://github.com/decionis/shield-swift", from: "0.1.0")
]
```

## First authorization

```swift
import ShieldKit

let shield = ShieldClient() // sandbox by default
let decision = try await shield.authorize(
    amount: 89,
    currency: "USD",
    purpose: "Book hotel",
    merchant: "Hilton"
)

switch decision.verdict {
case .allowed:
    execute()
case .approvalRequired:
    let final = try await shield.requestApproval(decisionId: decision.decisionId)
    if final.verdict == .allowed { execute() }
case .blocked:
    cancel()
}
```

Sandbox is local, deterministic, and requires no key. No real money can move.

## Approval flow

`ASK` is not an error and is not permission. Keep the action on hold, call `requestApproval`, and execute only if the returned decision is `.allowed`. Production approval is orchestrated through Presence behind the Shield API.

## Evidence

```swift
let dossier = try await shield.getDossier(decision.dossierId)
print(dossier.evidenceClass) // sandbox_fixture or production
```

## Errors

```swift
do {
    _ = try await shield.authorize(amount: 0, currency: "USD", purpose: "Buy")
} catch let error as ShieldError {
    print(error.code.rawValue)
    print(error.safeToExecute) // false
    print(error.action)
}
```

Network failures, timeouts, malformed responses, and invalid state never become ALLOW.

## Production configuration

```swift
let shield = ShieldClient(configuration: ShieldConfiguration(
    environment: .production,
    apiKey: serverIssuedKey,
    identity: ShieldIntegrationIdentity(
        appId: "app.travel.example",
        displayName: "Example Travel Agent",
        developer: "Example, Inc."
    )
))
```

Do not embed a long-lived production key in an App Store binary. Provision the user-bound app or agent identity from the consumer BFF and keep its credential on your trusted backend.

## Test

```bash
swift test
```

## Enforcement boundary

Applications must request Shield authorization before executing the consequential action. ShieldKit is not an after-the-fact transaction monitor and does not universally intercept arbitrary card or bank payments.

## License

Apache-2.0. Use of the hosted Shield service is governed separately.
