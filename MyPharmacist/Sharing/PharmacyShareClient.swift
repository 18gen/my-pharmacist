//
//  PharmacyShareClient.swift
//  MyPharmacist
//

import Foundation

/// Why talking to the pharmacy demo didn't work.
nonisolated enum ShareFailure: Error, Equatable, Sendable {
    /// No connection, or no answer in time.
    case offline
    /// This person isn't sharing any more: the demo was reset, or they were removed (404).
    case gone
    /// The app's token wasn't accepted (401, 403): this build can't share.
    case notAllowed
    /// The demo has as many people as it takes (409).
    case full
    /// Too many requests from this network just now (429).
    case busy
    /// The demo refused what was sent (400, 413).
    case refused
    /// The demo had a problem: a 5xx, or an answer it shouldn't give.
    case server(status: Int)

    init(status: Int) {
        switch status {
        case 401, 403: self = .notAllowed
        case 404: self = .gone
        case 409: self = .full
        case 429: self = .busy
        case 400, 413: self = .refused
        default: self = .server(status: status)
        }
    }

    /// Whether trying again later may work: not when the build or what it sends is wrong.
    var mayPassLater: Bool {
        switch self {
        case .offline, .busy, .server: true
        case .gone, .notAllowed, .full, .refused: false
        }
    }
}

/// The pharmacy demo's server as sharing uses it: `PharmacyShareClient`, or a fake in tests.
nonisolated protocol PharmacyDemo: Sendable {
    /// Starts sharing under `name`; answers the ID this phone shares as.
    func join(name: String) async throws(ShareFailure) -> String
    /// Replaces what the demo has for `id` with `snapshot`.
    func send(_ snapshot: ShareSnapshot, as id: String) async throws(ShareFailure)
    /// Stops sharing: the demo deletes this person.
    func leave(_ id: String) async throws(ShareFailure)
}

/// Talks to the pharmacy demo's dashboard (the my-pharmacist-dashboard project): its API
/// under /api, with the app's token in X-App-Token, as the pill check server takes it.
nonisolated struct PharmacyShareClient: PharmacyDemo {
    struct Configuration: Sendable, Equatable {
        /// The dashboard's address, like "https://my-pharmacist-dashboard.vercel.app".
        let baseURL: URL
        /// The token the dashboard checks, so only this app shares with it.
        let token: String

        /// From launch arguments in debug builds (`-pharmacyURL <address> -pharmacyToken
        /// <token>`, for trying it against `npm run dev`), else from Secrets.plist
        /// (PHARMACY_URL, PHARMACY_TOKEN). Nil without them: then there is no sharing.
        static func current(_ bundle: Bundle = .main) -> Configuration? {
            #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            func argument(_ name: String) -> String? {
                guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else { return nil }
                return arguments[index + 1]
            }
            if let address = argument("-pharmacyURL"), let token = argument("-pharmacyToken") {
                return from(["PHARMACY_URL": address, "PHARMACY_TOKEN": token])
            }
            #endif
            guard let url = bundle.url(forResource: "Secrets", withExtension: "plist"),
                  let values = NSDictionary(contentsOf: url) as? [String: Any] else { return nil }
            return from(values)
        }

        /// Nil when either is missing or still the example's.
        static func from(_ values: [String: Any]) -> Configuration? {
            func value(_ key: String) -> String? {
                (values[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard let address = value("PHARMACY_URL"), let baseURL = URL(string: address), isAllowed(baseURL),
                  let token = value("PHARMACY_TOKEN"), !token.isEmpty, !token.contains("paste-") else { return nil }
            return Configuration(baseURL: baseURL, token: token)
        }

        /// HTTPS; in debug builds also plain HTTP to "localhost", which iOS allows without an
        /// exception (App Transport Security), for the dashboard running on this Mac.
        static func isAllowed(_ url: URL) -> Bool {
            guard url.host() != nil else { return false }
            if url.scheme == "https" { return true }
            #if DEBUG
            return url.scheme == "http" && url.host() == "localhost"
            #else
            return false
            #endif
        }
    }

    let configuration: Configuration
    var timeout: TimeInterval = 15

    func join(name: String) async throws(ShareFailure) -> String {
        struct Joined: Decodable { let id: String }
        let body = try? JSONEncoder().encode(["name": name])
        let data = try await request("POST", "api/patients", body: body)
        guard let joined = try? JSONDecoder().decode(Joined.self, from: data), !joined.id.isEmpty else {
            throw .server(status: 201)
        }
        return joined.id
    }

    func send(_ snapshot: ShareSnapshot, as id: String) async throws(ShareFailure) {
        guard let body = try? snapshot.json() else { throw .refused }
        _ = try await request("PUT", "api/patients/\(id)", body: body)
    }

    func leave(_ id: String) async throws(ShareFailure) {
        _ = try await request("DELETE", "api/patients/\(id)", body: nil)
    }

    private func request(_ method: String, _ path: String, body: Data?) async throws(ShareFailure) -> Data {
        var request = URLRequest(url: configuration.baseURL.appending(path: path), timeoutInterval: timeout)
        request.httpMethod = method
        request.setValue(configuration.token, forHTTPHeaderField: "X-App-Token")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let data: Data, response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw .offline
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw ShareFailure(status: status) }
        return data
    }
}
