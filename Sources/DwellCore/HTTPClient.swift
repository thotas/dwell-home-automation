import Foundation

public enum HTTPError: Error, LocalizedError {
    case invalidURL(String)
    case requestFailed(String)
    case timeout
    case invalidResponse
    case httpFailure(status: Int, body: String)

    public var errorDescription: String? {
        switch self {
        case let .invalidURL(value): return "Invalid URL: \(value)"
        case let .requestFailed(reason): return "Network request failed: \(reason)"
        case .timeout: return "Network request timed out"
        case .invalidResponse: return "Invalid network response"
        case let .httpFailure(status, body): return "HTTP \(status): \(body)"
        }
    }
}

public final class HTTPClient {
    private let session: URLSession
    private let timeout: TimeInterval

    public init(session: URLSession = .shared, timeout: TimeInterval = 30) {
        self.session = session
        self.timeout = timeout
    }

    public func send(
        method: String,
        url: String,
        headers: [String: String] = [:],
        jsonBody: [String: Any]? = nil
    ) throws -> (status: Int, data: Data) {
        guard let endpoint = URL(string: url) else {
            throw HTTPError.invalidURL(url)
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = method
        request.timeoutInterval = timeout

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let jsonBody {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)
        }

        let semaphore = DispatchSemaphore(value: 0)
        let responseBox = NetworkResponseBox()

        let task = session.dataTask(with: request) { data, response, error in
            responseBox.set(data: data, response: response, error: error)
            semaphore.signal()
        }
        task.resume()

        let waitResult = semaphore.wait(timeout: .now() + timeout)
        if waitResult == .timedOut {
            task.cancel()
            throw HTTPError.timeout
        }

        if let outputError = responseBox.error {
            throw HTTPError.requestFailed(outputError.localizedDescription)
        }

        guard let outputResponse = responseBox.response as? HTTPURLResponse else {
            throw HTTPError.invalidResponse
        }

        let data = responseBox.data ?? Data()

        guard (200...299).contains(outputResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw HTTPError.httpFailure(status: outputResponse.statusCode, body: body)
        }

        return (outputResponse.statusCode, data)
    }

    public func sendJSON(
        method: String,
        url: String,
        headers: [String: String] = [:],
        jsonBody: [String: Any]? = nil
    ) throws -> [String: Any] {
        let response = try send(method: method, url: url, headers: headers, jsonBody: jsonBody)
        guard !response.data.isEmpty else {
            return [:]
        }

        let object = try JSONSerialization.jsonObject(with: response.data)
        guard let dictionary = object as? [String: Any] else {
            return [:]
        }
        return dictionary
    }
}

private final class NetworkResponseBox: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var data: Data?
    private(set) var response: URLResponse?
    private(set) var error: Error?

    func set(data: Data?, response: URLResponse?, error: Error?) {
        lock.lock()
        self.data = data
        self.response = response
        self.error = error
        lock.unlock()
    }
}
