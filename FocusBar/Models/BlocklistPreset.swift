import Foundation

struct BlockedApp: Identifiable, Codable, Equatable, Hashable, Sendable {
    var bundleID: String
    var name: String

    var id: String { bundleID }
}

struct ServiceCatalogEntry: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let domains: [String]
    let defaultEnabled: Bool
}

enum ServiceCatalog {
    static let services: [ServiceCatalogEntry] = [
        .init(id: "x", name: "X / Twitter", domains: ["x.com", "twitter.com"], defaultEnabled: true),
        .init(id: "facebook", name: "Facebook", domains: ["facebook.com"], defaultEnabled: true),
        .init(id: "instagram", name: "Instagram", domains: ["instagram.com"], defaultEnabled: true),
        .init(id: "tiktok", name: "TikTok", domains: ["tiktok.com"], defaultEnabled: true),
        .init(id: "reddit", name: "Reddit", domains: ["reddit.com"], defaultEnabled: true),
        .init(id: "linkedin", name: "LinkedIn", domains: ["linkedin.com"], defaultEnabled: true),
        .init(id: "snapchat", name: "Snapchat", domains: ["snapchat.com"], defaultEnabled: true),
        .init(id: "threads", name: "Threads", domains: ["threads.net"], defaultEnabled: true),
        .init(id: "youtube", name: "YouTube", domains: ["youtube.com", "youtu.be"], defaultEnabled: false)
    ]

    static var allDomains: Set<String> {
        Set(services.flatMap(\.domains))
    }

    static var defaultEnabledDomains: [String] {
        services.filter(\.defaultEnabled).flatMap(\.domains)
    }
}

struct BlocklistPreset: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var websiteDomains: [String]
    var apps: [BlockedApp]
    var isBuiltIn: Bool

    init(
        id: UUID = UUID(),
        name: String,
        websiteDomains: [String] = [],
        apps: [BlockedApp] = [],
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.websiteDomains = websiteDomains
        self.apps = apps
        self.isBuiltIn = isBuiltIn
    }

    static func socialMediaDefault() -> BlocklistPreset {
        BlocklistPreset(
            name: "Social media",
            websiteDomains: ServiceCatalog.defaultEnabledDomains,
            isBuiltIn: true
        )
    }

    var normalizedWebsiteDomains: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for domain in websiteDomains {
            guard let normalized = HostnameMatcher.sanitizedDomain(domain), !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            result.append(normalized)
        }
        return result
    }
}
