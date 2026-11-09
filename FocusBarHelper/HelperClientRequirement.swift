import Foundation

/// Builds the code-signing requirement the helper uses to reject XPC clients
/// that aren't the FocusBar app signed by the same team.
enum HelperClientRequirement {
    static func make() -> String? {
        let identifiers = SystemBlockingConstants.appBundleIdentifiers
            .map { "identifier \"\($0)\"" }
            .joined(separator: " or ")

        if let teamID = CodeSigningInfo.teamIdentifier() {
            return "(\(identifiers)) and anchor apple generic and certificate leaf[subject.OU] = \"\(teamID)\""
        }

        // A signed development build should always have a team identifier.
        // Keep a safe fallback for local signing setups that don't expose one.
        return "(\(identifiers)) and anchor apple generic"
    }
}
