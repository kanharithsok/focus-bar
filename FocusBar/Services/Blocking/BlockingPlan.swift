import Foundation

/// Pure decision logic for what a session should block. Kept separate from the
/// AppKit observers so it can be unit-tested without launching browsers/apps.
struct BlockingPlan: Equatable, Sendable {
    var appBlockingEnabled: Bool
    var websiteBlockingEnabled: Bool
    var systemWebsiteBlockingEnabled: Bool
    var suspended: Bool
    var appCount: Int
    var domainCount: Int
    var systemHostnameCount: Int
    var notes: [String]

    static func make(
        session: ActiveSession,
        preset: BlocklistPreset?,
        settings: AppSettings,
        blockedPageAvailable: Bool
    ) -> BlockingPlan {
        let isBreak = session.kind == .scatterfocus
        let breakAllowsBlocking = !isBreak || settings.blockDuringScatterfocus
        let suspended = session.blockingSuspended
        let domains = preset?.normalizedWebsiteDomains ?? []
        let apps = preset?.apps ?? []

        let appEnabled = settings.blockApps
            && breakAllowsBlocking
            && !suspended
            && !apps.isEmpty

        let websiteEnabled = settings.blockWebsites
            && breakAllowsBlocking
            && !suspended
            && !domains.isEmpty
            && blockedPageAvailable

        let systemHostnames = HostsBlocklistExpander.expand(domains: domains)
        let systemEnabled = settings.systemWideWebsiteBlockingEnabled
            && breakAllowsBlocking
            && !suspended
            && !systemHostnames.isEmpty

        var notes: [String] = []
        if preset == nil {
            notes.append("No blocklist preset selected.")
        } else {
            if settings.blockApps && apps.isEmpty {
                notes.append("No applications selected in this preset.")
            }
            if settings.blockWebsites && domains.isEmpty {
                notes.append("No websites selected in this preset.")
            }
            if settings.blockWebsites && !domains.isEmpty && !blockedPageAvailable {
                notes.append("The bundled blocked page is missing, so browser redirection is off.")
            }
        }
        if isBreak && !settings.blockDuringScatterfocus {
            notes.append("Blocking is off for Scatterfocus breaks in Settings.")
        }
        if suspended {
            notes.append("Blocking is suspended for this break.")
        }
        if settings.systemWideWebsiteBlockingEnabled && domains.isEmpty {
            notes.append("No websites are selected for system-wide blocking.")
        }
        if settings.appBlockingAction == .requestTerminate {
            notes.append("Quit requests are best-effort; apps may refuse.")
        }

        return BlockingPlan(
            appBlockingEnabled: appEnabled,
            websiteBlockingEnabled: websiteEnabled,
            systemWebsiteBlockingEnabled: systemEnabled,
            suspended: suspended,
            appCount: apps.count,
            domainCount: domains.count,
            systemHostnameCount: systemEnabled ? systemHostnames.count : 0,
            notes: notes
        )
    }
}
