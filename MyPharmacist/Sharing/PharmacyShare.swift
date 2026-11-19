//
//  PharmacyShare.swift
//  MyPharmacist
//

import Foundation
import Observation

/// Sharing with the pharmacy demo: whether this phone shares, under what name, and how the
/// last sending went.
///
/// Off until the person turns it on with a name. Then the whole snapshot goes to the demo
/// a moment after anything changes, and whenever the app comes back to the screen, which is
/// also how the phone learns that the demo was reset. No accounts: the demo knows this phone
/// by the ID it gave it, and shows the name.
@Observable
final class PharmacyShare {
    /// Who this phone shares as.
    nonisolated struct Session: Codable, Equatable, Sendable {
        /// What the demo gave this phone when it started sharing.
        let id: String
        /// What the person typed, as the pharmacy sees it.
        let name: String
    }

    /// How the last sending went.
    enum Delivery: Equatable {
        case idle
        case sending
        case sent(Date)
        case failed(ShareFailure)
    }

    /// The most characters in a name, as the demo takes them.
    static let nameLength = 40

    /// Who this phone shares as; nil while it doesn't.
    private(set) var session: Session? {
        didSet { save() }
    }
    private(set) var delivery = Delivery.idle
    /// Starting to share, between the button and the demo's answer.
    private(set) var isStarting = false
    /// Why starting to share didn't work, the last time it didn't.
    private(set) var startFailure: ShareFailure?
    /// The demo stopped this sharing (it was reset, or removed this person), not the person.
    private(set) var stoppedByDemo = false
    /// The name last shared under, offered again.
    private(set) var lastName = "" {
        didSet { save() }
    }

    /// Whether this build can share at all: it knows the demo's address and token.
    var isAvailable: Bool { demo != nil }

    /// What to send, made fresh each time: set by the app.
    @ObservationIgnored var makeSnapshot: ((Date) -> ShareSnapshot?)?

    @ObservationIgnored private let demo: (any PharmacyDemo)?
    @ObservationIgnored private let defaults: UserDefaults?
    @ObservationIgnored private let debounce: Duration
    @ObservationIgnored private let retryAfter: Duration
    @ObservationIgnored private let now: () -> Date
    /// The sending waiting for a burst of changes to end, or to try again.
    @ObservationIgnored private var waiting: Task<Void, Never>?
    @ObservationIgnored private var isSending = false
    @ObservationIgnored private var sendsAgain = false

    private static let key = "pharmacyShare.v1"

    private nonisolated struct Saved: Codable {
        var session: Session?
        var lastName: String
    }

    /// - Parameters:
    ///   - demo: The demo's server; nil when this build has none, and then there is no sharing.
    ///   - defaults: Where who this phone shares as is saved; nil keeps it in memory.
    ///   - debounce: How long after a change to send, so a burst of changes sends once.
    ///   - retryAfter: How long to wait before trying again after a sending failed.
    init(demo: (any PharmacyDemo)?, defaults: UserDefaults? = nil, debounce: Duration = .milliseconds(500),
         retryAfter: Duration = .seconds(10), now: @escaping () -> Date = { Date() }) {
        self.demo = demo
        self.defaults = defaults
        self.debounce = debounce
        self.retryAfter = retryAfter
        self.now = now
        if case .value(let saved) = defaults?.saved(Saved.self, forKey: Self.key) {
            session = saved.session
            lastName = saved.lastName
        }
    }

    /// What the name field keeps: no spaces around it, at most `nameLength` characters.
    static func tidied(_ name: String) -> String {
        String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(nameLength))
    }

    // MARK: Starting and stopping

    /// Starts sharing under `name`: the demo gives this phone an ID, and everything is sent at once.
    func start(name: String) async {
        let name = Self.tidied(name)
        guard let demo, !name.isEmpty, session == nil, !isStarting else { return }
        isStarting = true
        startFailure = nil
        defer { isStarting = false }
        do throws(ShareFailure) {
            let id = try await demo.join(name: name)
            lastName = name
            stoppedByDemo = false
            session = Session(id: id, name: name)
        } catch {
            startFailure = error
            return
        }
        await send()
    }

    /// Stops sharing: the demo deletes this person. Forgotten here even when the demo can't be
    /// reached; it then deletes them after 14 days without updates.
    func stop() async {
        guard let session else { return }
        waiting?.cancel()
        waiting = nil
        self.session = nil
        delivery = .idle
        stoppedByDemo = false
        do throws(ShareFailure) {
            try await demo?.leave(session.id)
        } catch {
            // Nothing more to do: see above.
        }
    }

    // MARK: Sending

    /// Something changed: sends a moment later, once for a burst of changes.
    func changed() {
        guard session != nil else { return }
        sendLater(after: debounce)
    }

    /// The app is on screen again: sends, which also finds out whether the demo was reset.
    func appBecameActive() {
        changed()
    }

    private func sendLater(after delay: Duration) {
        waiting?.cancel()
        waiting = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.send()
        }
    }

    /// Sends what there is now. One sending at a time, so an older snapshot never lands
    /// after a newer one: a change during a sending sends again once it is done.
    func send() async {
        guard let demo, let session else { return }
        if isSending {
            sendsAgain = true
            return
        }
        isSending = true
        defer {
            isSending = false
            sendsAgain = false
        }
        repeat {
            sendsAgain = false
            guard self.session == session, let snapshot = makeSnapshot?(now()) else { return }
            delivery = .sending
            do throws(ShareFailure) {
                try await demo.send(snapshot, as: session.id)
                delivery = .sent(now())
            } catch .gone {
                // Reset or removed on the dashboard: this phone no longer shares.
                if self.session == session {
                    waiting?.cancel()
                    self.session = nil
                    stoppedByDemo = true
                    delivery = .idle
                }
                return
            } catch {
                delivery = .failed(error)
                if error.mayPassLater { sendLater(after: retryAfter) }
                return
            }
        } while sendsAgain
    }

    private func save() {
        defaults?.save(Saved(session: session, lastName: lastName), forKey: Self.key)
    }
}
