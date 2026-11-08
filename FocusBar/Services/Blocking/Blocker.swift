import Foundation

struct BlockerConfiguration: Equatable, Sendable {
    var sessionID: UUID
    var websiteDomains: [String]
    var appBundleIDs: [String]
    var appAction: AppBlockingAction
    var blockedPageURL: URL?
}

struct BlockedEvent: Equatable, Sendable {
    var kind: BlockedAttemptKind
    var identifier: String
    var displayName: String
    var browserName: String?
    var detail: String?
    /// True only for failures that deserve a native notification (e.g. redirect failed).
    var notify: Bool = false
}

@MainActor
protocol Blocker: AnyObject {
    var id: String { get }
    var displayName: String { get }
    var isRunning: Bool { get }
    func start(configuration: BlockerConfiguration)
    func stop()
}
