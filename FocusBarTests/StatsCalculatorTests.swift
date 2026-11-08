import XCTest
@testable import FocusBar

final class StatsCalculatorTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2 // Monday
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testFocusMinutesForDayAndWeek() {
        let monday = date(2026, 11, 9)
        let tuesday = date(2026, 11, 10)
        let sessions = [
            makeRecord(startDate: monday, duration: 25 * 60),
            makeRecord(startDate: monday, duration: 50 * 60),
            makeRecord(startDate: tuesday, duration: 90 * 60),
            makeRecord(kind: .scatterfocus, startDate: monday, duration: 10 * 60)
        ]

        XCTAssertEqual(StatsCalculator.focusMinutes(sessions: sessions, on: monday, calendar: calendar), 75, accuracy: 0.001)
        XCTAssertEqual(StatsCalculator.focusMinutes(sessions: sessions, on: tuesday, calendar: calendar), 90, accuracy: 0.001)

        let week = StatsCalculator.weekInterval(containing: monday, calendar: calendar)
        XCTAssertEqual(StatsCalculator.focusMinutes(sessions: sessions, in: week), 165, accuracy: 0.001)
    }

    func testEarlyEndedSessionsContributeActualTime() {
        let day = date(2026, 11, 9)
        let session = makeRecord(
            startDate: day,
            duration: 50 * 60,
            actualDuration: 12 * 60,
            status: .endedEarly
        )
        XCTAssertEqual(StatsCalculator.focusMinutes(sessions: [session], on: day, calendar: calendar), 12, accuracy: 0.001)
    }

    func testAverageRatingIgnoresUnratedAndScatterfocus() {
        let day = date(2026, 11, 9)
        let sessions = [
            makeRecord(startDate: day, rating: 5),
            makeRecord(startDate: day, rating: 3),
            makeRecord(startDate: day, rating: nil),
            makeRecord(kind: .scatterfocus, startDate: day, rating: 1)
        ]
        XCTAssertEqual(StatsCalculator.averageRating(sessions: sessions) ?? 0, 4, accuracy: 0.001)
        XCTAssertNil(StatsCalculator.averageRating(sessions: [makeRecord(startDate: day, rating: nil)]))
    }

    func testDailyFocusReturnsOrderedWindow() {
        let now = date(2026, 11, 9, 18)
        let sessions = [
            makeRecord(startDate: date(2026, 11, 9), duration: 25 * 60),
            makeRecord(startDate: date(2026, 11, 7), duration: 50 * 60)
        ]

        let daily = StatsCalculator.dailyFocus(
            sessions: sessions,
            lastDays: 3,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(daily.count, 3)
        XCTAssertEqual(daily.map(\.minutes), [50, 0, 25])
        XCTAssertTrue(calendar.isDate(daily.last!.date, inSameDayAs: now))
    }

    func testTotalFocusMinutesExcludesBreaks() {
        let day = date(2026, 11, 9)
        let sessions = [
            makeRecord(startDate: day, duration: 25 * 60),
            makeRecord(startDate: day, duration: 50 * 60),
            makeRecord(kind: .scatterfocus, startDate: day, duration: 10 * 60)
        ]
        XCTAssertEqual(StatsCalculator.totalFocusMinutes(sessions: sessions), 75, accuracy: 0.001)
    }
}

final class SessionTimerTests: XCTestCase {
    func testFormattingRoundsUpAndClamps() {
        XCTAssertEqual(SessionTimer.format(0), "00:00")
        XCTAssertEqual(SessionTimer.format(-10), "00:00")
        XCTAssertEqual(SessionTimer.format(59.1), "01:00")
        XCTAssertEqual(SessionTimer.format(25 * 60), "25:00")
        XCTAssertEqual(SessionTimer.format(90 * 60 + 5), "90:05")
    }

    func testRemainingAndProgressClamp() {
        let start = Date(timeIntervalSince1970: 1000)
        let end = start.addingTimeInterval(100)

        XCTAssertEqual(SessionTimer.remaining(endDate: end, now: start), 100)
        XCTAssertEqual(SessionTimer.remaining(endDate: end, now: end.addingTimeInterval(20)), 0)
        XCTAssertEqual(SessionTimer.progress(startDate: start, endDate: end, now: start), 0, accuracy: 0.001)
        XCTAssertEqual(SessionTimer.progress(startDate: start, endDate: end, now: start.addingTimeInterval(50)), 0.5, accuracy: 0.001)
        XCTAssertEqual(SessionTimer.progress(startDate: start, endDate: end, now: end.addingTimeInterval(10)), 1, accuracy: 0.001)
    }

    func testRoundedMinutes() {
        XCTAssertEqual(SessionTimer.roundedMinutes(0), 0)
        XCTAssertEqual(SessionTimer.roundedMinutes(59), 1)
        XCTAssertEqual(SessionTimer.roundedMinutes(1499), 25)
    }
}
