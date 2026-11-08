import Foundation

struct DailyFocus: Identifiable, Equatable, Sendable {
    let date: Date
    let minutes: Double

    var id: Date { date }
}

/// Pure, testable statistics derived from session history.
enum StatsCalculator {
    static func focusMinutes(
        sessions: [SessionRecord],
        in interval: DateInterval?
    ) -> Double {
        guard let interval else { return 0 }
        return sessions
            .filter { $0.kind == .hyperfocus && interval.contains($0.startDate) }
            .reduce(0) { $0 + $1.actualDuration / 60 }
    }

    static func focusMinutes(
        sessions: [SessionRecord],
        on day: Date,
        calendar: Calendar = .current
    ) -> Double {
        focusMinutes(sessions: sessions, in: calendar.dateInterval(of: .day, for: day))
    }

    static func totalFocusMinutes(sessions: [SessionRecord]) -> Double {
        sessions
            .filter { $0.kind == .hyperfocus }
            .reduce(0) { $0 + $1.actualDuration / 60 }
    }

    static func averageRating(sessions: [SessionRecord]) -> Double? {
        let ratings = sessions.compactMap { session -> Int? in
            guard session.kind == .hyperfocus else { return nil }
            return session.rating
        }
        guard !ratings.isEmpty else { return nil }
        return Double(ratings.reduce(0, +)) / Double(ratings.count)
    }

    static func dailyFocus(
        sessions: [SessionRecord],
        lastDays: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> [DailyFocus] {
        guard lastDays > 0 else { return [] }
        let today = calendar.startOfDay(for: now)
        return (0..<lastDays).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DailyFocus(
                date: day,
                minutes: focusMinutes(sessions: sessions, on: day, calendar: calendar)
            )
        }
    }

    static func weekInterval(
        containing date: Date,
        calendar: Calendar = .current
    ) -> DateInterval? {
        calendar.dateInterval(of: .weekOfYear, for: date)
    }
}
