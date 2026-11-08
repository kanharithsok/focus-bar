import Foundation

struct BrowserDefinition: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let bundleID: String
    let urlScript: String
    let redirectScript: String
}

enum SupportedBrowsers {
    static let safari = BrowserDefinition(
        id: "safari",
        displayName: "Safari",
        bundleID: "com.apple.Safari",
        urlScript: """
        if application "Safari" is not running then return ""
        tell application "Safari"
            if (count of windows) is 0 then return ""
            return URL of current tab of front window
        end tell
        """,
        redirectScript: """
        on run argv
            set blockedURL to item 1 of argv
            tell application "Safari"
                if (count of windows) is 0 then return "no-window"
                set URL of current tab of front window to blockedURL
            end tell
            return "ok"
        end run
        """
    )

    static let chrome = BrowserDefinition(
        id: "chrome",
        displayName: "Google Chrome",
        bundleID: "com.google.Chrome",
        urlScript: """
        if application "Google Chrome" is not running then return ""
        tell application "Google Chrome"
            if (count of windows) is 0 then return ""
            return URL of active tab of front window
        end tell
        """,
        redirectScript: """
        on run argv
            set blockedURL to item 1 of argv
            tell application "Google Chrome"
                if (count of windows) is 0 then return "no-window"
                set URL of active tab of front window to blockedURL
            end tell
            return "ok"
        end run
        """
    )

    /// Only browsers whose scripting behavior has been deliberately implemented.
    static let all: [BrowserDefinition] = [safari, chrome]

    static func browser(for bundleID: String?) -> BrowserDefinition? {
        guard let bundleID else { return nil }
        return all.first { $0.bundleID == bundleID }
    }
}

enum BrowserAutomationPermission: String, Equatable, Sendable {
    case unknown
    case granted
    case denied
    case timedOut

    var displayName: String {
        switch self {
        case .unknown: return "Not checked"
        case .granted: return "Allowed"
        case .denied: return "Denied"
        case .timedOut: return "No response"
        }
    }
}
