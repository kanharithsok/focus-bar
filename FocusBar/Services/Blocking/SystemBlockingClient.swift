import Foundation
import Observation
import ServiceManagement

/// Owns the app side of the privileged helper connection and the heartbeat
/// lease. The helper removes the block if the app crashes or is force-quit.
@MainActor
@Observable
final class SystemBlockingClient {
    enum SessionState: Equatable {
        case idle
        case starting
        case active(hostnameCount: Int)
        case unavailable(String)
        case failed(String)
    }

    private(set) var sessionState: SessionState = .idle
    private(set) var lastError: String?

    @ObservationIgnored private let service: SystemBlockingService
    @ObservationIgnored private var connection: NSXPCConnection?
    @ObservationIgnored private var heartbeatTask: Task<Void, Never>?
    @ObservationIgnored private var currentSessionID: UUID?
    @ObservationIgnored private var currentLeaseID: UUID?
    @ObservationIgnored private var currentHostnames: [String] = []
    @ObservationIgnored private var needsBegin = false
    @ObservationIgnored private var isSending = false

    init(service: SystemBlockingService) {
        self.service = service
    }

    func start(sessionID: UUID, hostnames: [String]) {
        guard !hostnames.isEmpty else {
            stop()
            return
        }

        let validated: [String]
        do {
            validated = try HostsHostnameValidator.validatedHostnames(hostnames)
        } catch {
            stop()
            sessionState = .unavailable(error.localizedDescription)
            return
        }

        // Avoid rewriting hosts when an unrelated setting changed but the
        // system block is already running for the same session and hostnames.
        if currentSessionID == sessionID,
           currentHostnames == validated,
           heartbeatTask != nil {
            return
        }

        // A new begin atomically replaces the helper's marked hosts section,
        // so an old connection can be dropped without racing an end call.
        reset(callEnd: false)

        currentSessionID = sessionID
        currentLeaseID = UUID()
        currentHostnames = validated
        needsBegin = true
        sessionState = .starting
        service.refresh()

        if service.isAdHocSigned {
            lastError = nil
            sessionState = .unavailable(adHocMessage)
            return
        }

        if service.helperStatus != .enabled {
            lastError = nil
            sessionState = .unavailable(unavailableMessage(for: service.helperStatus))
        }
        // Keep polling even when the helper is not ready. This lets the app
        // pick up approval in System Settings without restarting the session.
        startHeartbeat()
    }

    func stop() {
        reset(callEnd: true)
    }

    private func reset(callEnd: Bool) {
        heartbeatTask?.cancel()
        heartbeatTask = nil

        let sessionID = currentSessionID
        let leaseID = currentLeaseID
        let connection = self.connection
        currentSessionID = nil
        currentLeaseID = nil
        currentHostnames = []
        needsBegin = false
        isSending = false
        self.connection = nil

        if let connection {
            if callEnd, let sessionID, let leaseID {
                end(
                    connection: connection,
                    sessionID: sessionID,
                    leaseID: leaseID
                ) { [weak self, weak connection] in
                    Task { @MainActor in
                        guard let self, let connection else { return }
                        self.invalidate(connection)
                    }
                }
            } else {
                connection.invalidate()
            }
        }

        sessionState = .idle
    }

    func refreshHelperStatus() {
        service.refresh()
        if service.isAdHocSigned {
            lastError = nil
            sessionState = .unavailable(adHocMessage)
            return
        }
        if currentSessionID != nil, service.helperStatus != .enabled {
            lastError = nil
            sessionState = .unavailable(unavailableMessage(for: service.helperStatus))
        }
    }

    func clearError() {
        lastError = nil
    }

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                if Task.isCancelled { return }
                try? await Task.sleep(
                    nanoseconds: UInt64(SystemBlockingConstants.heartbeatInterval * 1_000_000_000)
                )
            }
        }
    }

    private func tick() async {
        guard let sessionID = currentSessionID,
              let leaseID = currentLeaseID,
              !isSending
        else {
            return
        }

        service.refresh()
        if service.isAdHocSigned {
            lastError = nil
            sessionState = .unavailable(adHocMessage)
            return
        }
        guard service.helperStatus == .enabled else {
            lastError = nil
            sessionState = .unavailable(unavailableMessage(for: service.helperStatus))
            return
        }

        isSending = true
        defer { isSending = false }

        let connection = ensureConnection()
        let hostnames = currentHostnames

        if needsBegin {
            let result = await begin(
                connection: connection,
                sessionID: sessionID,
                leaseID: leaseID,
                hostnames: hostnames
            )
            guard currentSessionID == sessionID, currentLeaseID == leaseID else { return }
            switch result {
            case .success:
                needsBegin = false
                lastError = nil
                sessionState = .active(hostnameCount: hostnames.count)
            case .failure(let error):
                lastError = error.localizedDescription
                sessionState = .failed(error.localizedDescription)
            }
        } else {
            let result = await heartbeat(
                connection: connection,
                sessionID: sessionID,
                leaseID: leaseID
            )
            guard currentSessionID == sessionID, currentLeaseID == leaseID else { return }
            switch result {
            case .success:
                lastError = nil
                sessionState = .active(hostnameCount: hostnames.count)
            case .failure(let error):
                needsBegin = true
                lastError = error.localizedDescription
                sessionState = .failed(error.localizedDescription)
            }
        }
    }

    private func ensureConnection() -> NSXPCConnection {
        if let connection {
            return connection
        }

        let connection = NSXPCConnection(
            machServiceName: SystemBlockingConstants.machServiceName,
            options: .privileged
        )
        connection.remoteObjectInterface = NSXPCInterface(with: FocusBarHelperXPCProtocol.self)
        connection.invalidationHandler = { [weak self, weak connection] in
            Task { @MainActor in
                guard let self, let connection, self.connection === connection else { return }
                self.connection = nil
                if self.currentSessionID != nil {
                    self.needsBegin = true
                    self.sessionState = .failed("The system helper connection closed.")
                }
            }
        }
        connection.interruptionHandler = { [weak self, weak connection] in
            Task { @MainActor in
                guard let self, let connection, self.connection === connection else { return }
                self.needsBegin = true
                if self.currentSessionID != nil {
                    self.sessionState = .failed("The system helper connection was interrupted.")
                }
            }
        }
        connection.resume()
        self.connection = connection
        return connection
    }

    private func begin(
        connection: NSXPCConnection,
        sessionID: UUID,
        leaseID: UUID,
        hostnames: [String]
    ) async -> Result<Void, SystemBlockingClientError> {
        await withCheckedContinuation { continuation in
            let gate = ReplyGate()
            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
                gate.resume {
                    continuation.resume(
                        returning: .failure(.connection(error.localizedDescription))
                    )
                }
            }) as? FocusBarHelperXPCProtocol else {
                gate.resume {
                    continuation.resume(
                        returning: .failure(.connection("The system helper isn't available."))
                    )
                }
                return
            }

            proxy.beginBlocking(
                sessionID: sessionID.uuidString,
                leaseID: leaseID.uuidString,
                hostnames: hostnames,
                leaseSeconds: SystemBlockingConstants.leaseSeconds
            ) { success, message in
                gate.resume {
                    if success {
                        continuation.resume(returning: .success(()))
                    } else {
                        continuation.resume(
                            returning: .failure(
                                .helper(message ?? "The system helper rejected the request.")
                            )
                        )
                    }
                }
            }
        }
    }

    private func heartbeat(
        connection: NSXPCConnection,
        sessionID: UUID,
        leaseID: UUID
    ) async -> Result<Void, SystemBlockingClientError> {
        await withCheckedContinuation { continuation in
            let gate = ReplyGate()
            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
                gate.resume {
                    continuation.resume(
                        returning: .failure(.connection(error.localizedDescription))
                    )
                }
            }) as? FocusBarHelperXPCProtocol else {
                gate.resume {
                    continuation.resume(
                        returning: .failure(.connection("The system helper isn't available."))
                    )
                }
                return
            }

            proxy.heartbeat(
                sessionID: sessionID.uuidString,
                leaseID: leaseID.uuidString,
                leaseSeconds: SystemBlockingConstants.leaseSeconds
            ) { success, message in
                gate.resume {
                    if success {
                        continuation.resume(returning: .success(()))
                    } else {
                        continuation.resume(
                            returning: .failure(
                                .helper(message ?? "The system helper lost the session lease.")
                            )
                        )
                    }
                }
            }
        }
    }

    private func end(
        connection: NSXPCConnection,
        sessionID: UUID,
        leaseID: UUID,
        completion: @escaping () -> Void
    ) {
        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in
            completion()
        }) as? FocusBarHelperXPCProtocol else {
            completion()
            return
        }

        proxy.endBlocking(
            sessionID: sessionID.uuidString,
            leaseID: leaseID.uuidString
        ) { _ in
            completion()
        }

        // If the helper is wedged, don't leave the connection alive forever.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            completion()
        }
    }

    private func invalidate(_ connection: NSXPCConnection) {
        if self.connection === connection {
            self.connection = nil
        }
        connection.invalidate()
    }

    private var adHocMessage: String {
        "This development build is ad-hoc signed. System-wide blocking only works from the signed app in /Applications or a build signed with your Apple Development team."
    }

    private func unavailableMessage(for status: SMAppService.Status) -> String {
        switch status {
        case .enabled:
            return ""
        case .requiresApproval:
            return "The system helper is waiting for approval in System Settings > General > Login Items."
        case .notFound, .notRegistered:
            return "The system helper isn't installed. Enable system-wide blocking in Settings."
        default:
            return "The system helper status is unknown."
        }
    }
}

private enum SystemBlockingClientError: LocalizedError {
    case connection(String)
    case helper(String)

    var errorDescription: String? {
        switch self {
        case .connection(let message): return message
        case .helper(let message): return message
        }
    }
}

/// Guarantees an XPC continuation is resumed exactly once even if both the
/// reply block and the connection error handler fire.
private final class ReplyGate {
    private let lock = NSLock()
    private var didResume = false

    func resume(_ action: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else { return }
        didResume = true
        action()
    }
}
