import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol ShieldTransport: Sendable {
    func send(
        url: URL,
        method: String,
        headers: [String: String],
        body: Data?,
        timeout: TimeInterval
    ) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionShieldTransport: ShieldTransport {
    public init() {}

    public func send(
        url: URL,
        method: String,
        headers: [String: String],
        body: Data?,
        timeout: TimeInterval
    ) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = method
        request.httpBody = body
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ShieldError(
                code: .invalidResponse,
                message: "Shield returned a non-HTTP response.",
                action: "Keep the transaction on hold and retry through a supported HTTPS transport."
            )
        }
        return (data, http)
    }
}
