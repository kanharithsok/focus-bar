import Foundation
import os

/// Owns the /etc/hosts section and the fail-open lease.
///
/// All mutable state is confined to `queue`. XPC methods can arrive on any
/// queue, so each one hops onto the serial queue before touching the hosts
/// file or the lease.
final class HostsBlockingService: NSObject, FocusBarHelperXPCProtocol {
    private struct Lease {
        let sessionID: String
        let leaseID: String
        let hostnames: [String]
        var expiresAt: Date
    }

    private let queue = DispatchQueue(label: "com.kanharithsok.FocusBar.helper.hosts")
    private let manager: HostsBlockFileManager
    private let logger = Logger(
        subsystem: SystemBlockingConstants.machServiceName,
        category: "service"
    )

    private var lease: Lease?
    private var timer: DispatchSourceTimer?

    init(manager: HostsBlockFileManager = HostsBlockFileManager()) {
        self.manager = manager
        super.init()

        // A daemon restart or reboot must not leave a stale system block.
        // The app re-applies the block on its next heartbeat if a session is
        // still active.
        queue.async { [weak self] in
            do {
                try self?.manager.removeBlock()
            } catch {
                self?.logger.error(
                    "Couldn't clear stale hosts block: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    deinit {
        timer?.cancel()
    }

    func beginBlocking(
        sessionID: String,
        leaseID: String,
        hostnames: [String],
        leaseSeconds: Double,
        reply: @escaping (Bool, String?) -> Void
    ) {
        queue.async { [weak self] in
            guard let self else {
                reply(false, "The system helper is shutting down.")
                return
            }

            do {
                guard UUID(uuidString: sessionID) != nil else {
                    throw HostsBlockingError.invalidSessionID
                }
                guard UUID(uuidString: leaseID) != nil else {
                    throw HostsBlockingError.invalidLeaseID
                }
                let duration = self.clampedLease(leaseSeconds)
                let validated = try HostsHostnameValidator.validatedHostnames(hostnames)
                try self.manager.apply(
                    hostnames: validated,
                    sessionID: UUID(uuidString: sessionID)!
                )

                self.lease = Lease(
                    sessionID: sessionID,
                    leaseID: leaseID,
                    hostnames: validated,
                    expiresAt: Date().addingTimeInterval(duration)
                )
                self.startTimerIfNeeded()
                self.logger.info("System block active with \(validated.count) hostnames")
                reply(true, nil)
            } catch {
                self.logger.error(
                    "Couldn't begin system block: \(error.localizedDescription, privacy: .public)"
                )
                reply(false, error.localizedDescription)
            }
        }
    }

    func heartbeat(
        sessionID: String,
        leaseID: String,
        leaseSeconds: Double,
        reply: @escaping (Bool, String?) -> Void
    ) {
        queue.async { [weak self] in
            guard let self else {
                reply(false, "The system helper is shutting down.")
                return
            }
            guard var lease = self.lease,
                  lease.sessionID == sessionID,
                  lease.leaseID == leaseID
            else {
                reply(false, "No matching system block is active.")
                return
            }

            // Reassert the marked section if another tool removed it while the
            // session is still active.
            do {
                if try !self.manager.isBlockPresent() {
                    guard let uuid = UUID(uuidString: lease.sessionID) else {
                        throw HostsBlockingError.invalidSessionID
                    }
                    try self.manager.apply(hostnames: lease.hostnames, sessionID: uuid)
                    self.logger.notice("Re-applied missing system block")
                }
            } catch {
                self.logger.error(
                    "Couldn't reassert the system block: \(error.localizedDescription, privacy: .public)"
                )
                reply(false, error.localizedDescription)
                return
            }

            lease.expiresAt = Date().addingTimeInterval(self.clampedLease(leaseSeconds))
            self.lease = lease
            reply(true, nil)
        }
    }

    func endBlocking(
        sessionID: String,
        leaseID: String,
        reply: @escaping (Bool) -> Void
    ) {
        queue.async { [weak self] in
            guard let self else {
                reply(false)
                return
            }

            if let lease = self.lease,
               lease.sessionID != sessionID || lease.leaseID != leaseID {
                reply(false)
                return
            }

            do {
                try self.manager.removeBlock()
                self.lease = nil
                self.stopTimer()
                self.logger.info("System block ended")
                reply(true)
            } catch {
                self.logger.error(
                    "Couldn't end system block: \(error.localizedDescription, privacy: .public)"
                )
                reply(false)
            }
        }
    }

    func status(reply: @escaping (Bool, Int, String?) -> Void) {
        queue.async { [weak self] in
            guard let self else {
                reply(false, 0, "The system helper is shutting down.")
                return
            }
            reply(self.lease != nil, self.lease?.hostnames.count ?? 0, nil)
        }
    }

    /// Best-effort cleanup for a clean daemon shutdown (unregister, logout,
    /// reboot). Stale sections are also removed on the next launch.
    func cleanupForTermination() {
        queue.sync {
            do {
                try manager.removeBlock()
            } catch {
                logger.error(
                    "Couldn't clean up hosts block on shutdown: \(error.localizedDescription, privacy: .public)"
                )
            }
            lease = nil
            stopTimer()
        }
    }

    private func clampedLease(_ requested: Double) -> TimeInterval {
        min(max(requested, 5), 120)
    }

    private func startTimerIfNeeded() {
        guard timer == nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 5, repeating: 5, leeway: .seconds(1))
        timer.setEventHandler { [weak self] in
            self?.expireIfNeeded()
        }
        timer.resume()
        self.timer = timer
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    private func expireIfNeeded() {
        guard let lease else {
            stopTimer()
            return
        }
        guard Date() >= lease.expiresAt else { return }

        logger.notice("System block lease expired; removing hosts section")
        do {
            try manager.removeBlock()
        } catch {
            logger.error(
                "Couldn't remove expired hosts block: \(error.localizedDescription, privacy: .public)"
            )
        }
        self.lease = nil
        stopTimer()
    }
}
