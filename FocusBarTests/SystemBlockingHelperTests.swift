import ServiceManagement
import XCTest
@testable import FocusBar

@MainActor
final class SystemBlockingHelperTests: XCTestCase {
    func testDaemonStatusIsReadableWithoutRegistering() {
        let service = SystemBlockingService()
        service.refresh()

        // On macOS 27.2 a never-registered daemon reports .notFound (3), not
        // .notRegistered. Both are valid "not installed yet" states.
        switch service.helperStatus {
        case .notRegistered, .enabled, .requiresApproval, .notFound:
            break
        @unknown default:
            XCTFail("Unknown SMAppService.Status: \(service.helperStatus)")
        }
    }
}
