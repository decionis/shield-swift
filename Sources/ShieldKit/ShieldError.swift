import Foundation

public enum ShieldErrorCode: String, Sendable {
    case invalidRequest = "SHIELD_INVALID_REQUEST"
    case invalidState = "SHIELD_INVALID_STATE"
    case productionKeyRequired = "SHIELD_PRODUCTION_KEY_REQUIRED"
    case integrationIdentityRequired = "SHIELD_INTEGRATION_IDENTITY_REQUIRED"
    case authenticationFailed = "SHIELD_AUTHENTICATION_FAILED"
    case rateLimited = "SHIELD_RATE_LIMITED"
    case timedOut = "SHIELD_TIMEOUT"
    case unavailable = "SHIELD_UNAVAILABLE"
    case environmentMismatch = "SHIELD_ENVIRONMENT_MISMATCH"
    case idempotencyContextMismatch = "SHIELD_IDEMPOTENCY_CONTEXT_MISMATCH"
    case invalidResponse = "SHIELD_INVALID_RESPONSE"
}

public struct ShieldError: Error, LocalizedError, CustomStringConvertible, Sendable {
    public let code: ShieldErrorCode
    public let message: String
    public let action: String
    public let retryable: Bool
    public let safeToExecute = false
    public let status: Int?

    public init(
        code: ShieldErrorCode,
        message: String,
        action: String,
        retryable: Bool = false,
        status: Int? = nil
    ) {
        self.code = code
        self.message = message
        self.action = action
        self.retryable = retryable
        self.status = status
    }

    public var errorDescription: String? { message }

    public var description: String {
        "\(code.rawValue)\n\n\(message)\n\nDo not execute the transaction.\n\nNext: \(action)"
    }
}
