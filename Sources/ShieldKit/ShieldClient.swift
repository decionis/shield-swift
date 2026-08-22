import Foundation

public struct ShieldConfiguration: Sendable {
    public let environment: ShieldEnvironment
    public let apiKey: String?
    public let baseURL: URL
    public let identity: ShieldIntegrationIdentity?
    public let timeout: TimeInterval

    public init(
        environment: ShieldEnvironment = .sandbox,
        apiKey: String? = nil,
        baseURL: URL = URL(string: "https://api.decionis.com")!,
        identity: ShieldIntegrationIdentity? = nil,
        timeout: TimeInterval = 8
    ) {
        self.environment = environment
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.identity = identity
        self.timeout = timeout
    }
}

public actor ShieldClient {
    public let configuration: ShieldConfiguration
    private let transport: any ShieldTransport
    private var decisions: [String: ShieldDecision] = [:]
    private var dossiers: [String: ShieldDossier] = [:]

    public init(
        configuration: ShieldConfiguration = ShieldConfiguration(),
        transport: any ShieldTransport = URLSessionShieldTransport()
    ) {
        self.configuration = configuration
        self.transport = transport
    }

    public func authorize(
        amount: Double,
        currency: String,
        purpose: String,
        merchant: String? = nil,
        category: String? = nil,
        agentId: String? = nil,
        transactionType: ShieldTransactionType? = nil,
        metadata: [String: JSONValue]? = nil,
        sandboxScenario: ShieldSandboxScenario? = nil,
        idempotencyKey: String? = nil
    ) async throws -> ShieldDecision {
        try await authorize(
            SpendingRequest(
                amount: amount,
                currency: currency,
                purpose: purpose,
                merchant: merchant,
                category: category,
                agentId: agentId,
                transactionType: transactionType,
                metadata: metadata
            ),
            sandboxScenario: sandboxScenario,
            idempotencyKey: idempotencyKey
        )
    }

    public func authorize(
        _ request: SpendingRequest,
        sandboxScenario: ShieldSandboxScenario? = nil,
        idempotencyKey: String? = nil
    ) async throws -> ShieldDecision {
        let normalized = try validate(request)
        if sandboxScenario != nil, configuration.environment != .sandbox {
            throw ShieldError(
                code: .environmentMismatch,
                message: "Sandbox scenarios cannot be sent to production.",
                action: "Remove sandboxScenario or configure the sandbox environment."
            )
        }
        if configuration.environment == .sandbox {
            let (decision, dossier) = try ShieldSandbox.evaluate(request: normalized, scenario: sandboxScenario)
            decisions[decision.decisionId] = decision
            dossiers[dossier.dossierId] = dossier
            return decision
        }
        try validateProductionConfiguration()
        let decision: ShieldDecision = try await send(
            path: "/v1/shield/authorize",
            method: "POST",
            body: normalized,
            additionalHeaders: idempotencyKey.map { ["Idempotency-Key": $0] } ?? [:]
        )
        decisions[decision.decisionId] = decision
        return decision
    }

    public func requestApproval(decisionId: String) async throws -> ShieldDecision {
        let current = try await getDecision(decisionId)
        guard current.verdict == .approvalRequired else {
            throw ShieldError(
                code: .invalidState,
                message: "Decision \(decisionId) does not require approval.",
                action: current.verdict == .allowed ? "Execute this exact action once." : "Cancel the transaction."
            )
        }
        if configuration.environment == .sandbox {
            let approved = ShieldDecision(
                verdict: .allowed,
                approvalStatus: .approved,
                reason: "The sandbox user approved this purchase through a simulated Presence flow.",
                reasonCode: "USER_APPROVED",
                requestId: current.requestId,
                decisionId: current.decisionId,
                dossierId: current.dossierId,
                environment: .sandbox,
                advanced: current.advanced
            )
            decisions[decisionId] = approved
            if let dossier = dossiers[current.dossierId] {
                dossiers[current.dossierId] = ShieldDossier(
                    dossierId: dossier.dossierId,
                    decisionId: dossier.decisionId,
                    verdict: .allowed,
                    reasonCode: "USER_APPROVED",
                    environment: .sandbox,
                    evidenceClass: dossier.evidenceClass,
                    evidenceHash: dossier.evidenceHash,
                    evaluation: dossier.evaluation
                )
            }
            return approved
        }
        let decision: ShieldDecision = try await send(
            path: "/v1/shield/decisions/\(decisionId)/approval",
            method: "POST",
            body: EmptyBody()
        )
        decisions[decisionId] = decision
        return decision
    }

    public func getDecision(_ decisionId: String) async throws -> ShieldDecision {
        if configuration.environment == .sandbox {
            guard let decision = decisions[decisionId] else {
                throw ShieldError(code: .invalidRequest, message: "Sandbox decision \(decisionId) is unavailable.", action: "Authorize the sandbox request before reading its decision.")
            }
            return decision
        }
        return try await send(path: "/v1/shield/decisions/\(decisionId)", method: "GET", body: Optional<EmptyBody>.none)
    }

    public func getDossier(_ dossierId: String) async throws -> ShieldDossier {
        if configuration.environment == .sandbox {
            guard let dossier = dossiers[dossierId] else {
                throw ShieldError(code: .invalidRequest, message: "Sandbox dossier \(dossierId) is unavailable.", action: "Authorize the sandbox request before reading its dossier.")
            }
            return dossier
        }
        return try await send(path: "/v1/shield/dossiers/\(dossierId)", method: "GET", body: Optional<EmptyBody>.none)
    }

    private func validate(_ request: SpendingRequest) throws -> SpendingRequest {
        guard request.amount.isFinite, request.amount > 0 else {
            throw ShieldError(code: .invalidRequest, message: "The spending request amount is invalid.", action: "Use a finite amount greater than zero in major currency units.")
        }
        let currency = request.currency.uppercased()
        guard currency.range(of: "^[A-Z]{3}$", options: .regularExpression) != nil else {
            throw ShieldError(code: .invalidRequest, message: "The spending request currency is invalid.", action: "Use a three-letter ISO 4217 code such as USD or EUR.")
        }
        let purpose = request.purpose.trimmingCharacters(in: .whitespacesAndNewlines)
        guard purpose.count >= 3, purpose.count <= 240 else {
            throw ShieldError(code: .invalidRequest, message: "The spending request purpose is invalid.", action: "Describe the purchase in 3 to 240 characters.")
        }
        return SpendingRequest(amount: request.amount, currency: currency, purpose: purpose, merchant: request.merchant, category: request.category, agentId: request.agentId, transactionType: request.transactionType, metadata: request.metadata)
    }

    private func validateProductionConfiguration() throws {
        guard configuration.apiKey?.isEmpty == false else {
            throw ShieldError(code: .productionKeyRequired, message: "Production authorization requires DECIONIS_SHIELD_API_KEY.", action: "Create a production integration and configure its server-side API key.")
        }
        guard configuration.identity != nil else {
            throw ShieldError(code: .integrationIdentityRequired, message: "Production authorization requires a registered app identity.", action: "Configure the app ID and display name from the Shield developer dashboard.")
        }
    }

    private func send<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body?,
        additionalHeaders: [String: String] = [:]
    ) async throws -> Response {
        try validateProductionConfiguration()
        let url = configuration.baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        let encoded = try body.map { try JSONEncoder().encode($0) }
        do {
            let (data, response) = try await transport.send(
                url: url,
                method: method,
                headers: [
                    "Accept": "application/json",
                    "Authorization": "Bearer \(configuration.apiKey!)",
                    "Content-Type": "application/json",
                    "X-Shield-App-Id": configuration.identity!.appId,
                    "X-Shield-Environment": configuration.environment.rawValue,
                ].merging(additionalHeaders) { _, replacement in replacement },
                body: encoded,
                timeout: configuration.timeout
            )
            guard (200 ..< 300).contains(response.statusCode) else {
                throw error(status: response.statusCode, data: data)
            }
            do { return try JSONDecoder().decode(Response.self, from: data) }
            catch {
                throw ShieldError(code: .invalidResponse, message: "Shield returned a response outside the ALLOW / ASK / BLOCK contract.", action: "Keep the transaction on hold and report the request trace to Decionis.")
            }
        } catch let error as ShieldError { throw error }
        catch {
            let timedOut = (error as? URLError)?.code == .timedOut
            throw ShieldError(
                code: timedOut ? .timedOut : .unavailable,
                message: timedOut ? "Shield did not return a decision before the timeout." : "Shield could not be reached.",
                action: "Keep the transaction on hold and retry with the same request context.",
                retryable: true
            )
        }
    }

    private func error(status: Int, data: Data) -> ShieldError {
        let server = try? JSONDecoder().decode(ShieldServerError.self, from: data)
        switch status {
        case 401, 403:
            return ShieldError(code: .authenticationFailed, message: "Shield could not authenticate this integration.", action: "Check the production key and registered app identity.", status: status)
        case 409:
            if server?.error == ShieldErrorCode.idempotencyContextMismatch.rawValue {
                return ShieldError(
                    code: .idempotencyContextMismatch,
                    message: server?.message ?? "This idempotency key is bound to a different spending request.",
                    action: "Use the same key only for an exact retry, or create a new key for a new action.",
                    status: status
                )
            }
            if server?.error == "SHIELD_DECISION_NOT_AWAITING_APPROVAL" {
                return ShieldError(code: .invalidState, message: server?.message ?? "This decision is not awaiting approval.", action: "Execute only an ALLOW and cancel a BLOCK.", status: status)
            }
            return ShieldError(code: .environmentMismatch, message: server?.message ?? "Sandbox and production configuration were mixed.", action: "Use matching credentials and environment settings.", status: status)
        case 429:
            return ShieldError(code: .rateLimited, message: "Shield is receiving too many authorization requests.", action: "Retry with exponential backoff and the same request context.", retryable: true, status: status)
        default:
            return ShieldError(code: .unavailable, message: "Shield authorization failed with HTTP \(status).", action: "Keep the transaction on hold and retry only when Shield is available.", retryable: status >= 500, status: status)
        }
    }
}

private struct EmptyBody: Codable {}
private struct ShieldServerError: Decodable {
    let error: String?
    let message: String?
}
