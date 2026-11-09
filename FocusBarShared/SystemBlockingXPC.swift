import Foundation

enum SystemBlockingConstants {
    static let machServiceName = "com.kanharithsok.FocusBar.helper"
    static let plistName = "com.kanharithsok.FocusBar.helper.plist"
    static let appBundleIdentifiers = [
        "com.kanharithsok.FocusBar",
        "com.kanharithsok.FocusBar.debug"
    ]

    /// The helper removes the hosts block if it doesn't hear from the app for
    /// this long. Fail-open: a crashed or force-quit app never leaves a
    /// permanent block behind.
    static let leaseSeconds: TimeInterval = 30
    static let heartbeatInterval: TimeInterval = 8
    static let maximumHostnames = 2_000
}

/// Shared XPC contract between the app and the privileged helper.
///
/// Only primitive XPC-compatible types are used so both targets can share
/// this file without a framework.
@objc protocol FocusBarHelperXPCProtocol {
    func beginBlocking(
        sessionID: String,
        leaseID: String,
        hostnames: [String],
        leaseSeconds: Double,
        reply: @escaping (Bool, String?) -> Void
    )

    func heartbeat(
        sessionID: String,
        leaseID: String,
        leaseSeconds: Double,
        reply: @escaping (Bool, String?) -> Void
    )

    func endBlocking(
        sessionID: String,
        leaseID: String,
        reply: @escaping (Bool) -> Void
    )

    func status(
        reply: @escaping (Bool, Int, String?) -> Void
    )
}
