import Foundation

enum HostnameMatcher {
    /// Extracts a normalized hostname from a URL string. Returns nil for non-web URLs.
    static func hostname(from urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), let host = url.host, !host.isEmpty {
            return normalize(host)
        }

        // Tolerate hostnames pasted without a scheme ("x.com/path").
        if !trimmed.contains("://"),
           let url = URL(string: "https://\(trimmed)"),
           let host = url.host,
           !host.isEmpty {
            return normalize(host)
        }

        return nil
    }

    /// Lowercases, trims, removes a trailing root dot and a leading `www.`.
    static func normalize(_ host: String) -> String {
        var normalized = host
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        while normalized.hasSuffix(".") {
            normalized.removeLast()
        }
        if normalized.hasPrefix("www.") {
            normalized.removeFirst(4)
        }
        return normalized
    }

    /// Exact domain or subdomain match. `notx.com` and `x.com.evil.com` never match `x.com`.
    static func matches(host: String, blockedDomains: [String]) -> Bool {
        let normalizedHost = normalize(host)
        guard !normalizedHost.isEmpty else { return false }

        return blockedDomains.contains { domain in
            let normalizedDomain = normalize(domain)
            guard !normalizedDomain.isEmpty else { return false }
            return normalizedHost == normalizedDomain || normalizedHost.hasSuffix(".\(normalizedDomain)")
        }
    }

    /// Accepts a bare domain or a full URL and returns a safe domain, or nil.
    static func sanitizedDomain(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let candidate = hostname(from: trimmed) ?? normalize(trimmed)
        guard !candidate.isEmpty,
              !candidate.contains("/"),
              !candidate.contains(" "),
              !candidate.contains("@"),
              candidate.contains("."),
              candidate != ".",
              !candidate.hasPrefix("."),
              !candidate.hasSuffix(".")
        else {
            return nil
        }
        return candidate
    }
}
