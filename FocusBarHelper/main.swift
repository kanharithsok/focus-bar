import Darwin
import Foundation
import os

/// M6 privileged helper.
///
/// The daemon owns the marked /etc/hosts section and refuses XPC connections
/// from anything other than the FocusBar app signed by the same team.
final class FocusBarHelperListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let service: HostsBlockingService
    private let logger = Logger(
        subsystem: SystemBlockingConstants.machServiceName,
        category: "listener"
    )

    init(service: HostsBlockingService) {
        self.service = service
        super.init()
    }

    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        logger.info("Accepting FocusBar XPC connection")
        newConnection.exportedInterface = NSXPCInterface(with: FocusBarHelperXPCProtocol.self)
        newConnection.exportedObject = service
        newConnection.invalidationHandler = { [logger] in
            logger.info("FocusBar XPC connection invalidated")
        }
        newConnection.resume()
        return true
    }
}

if CommandLine.arguments.contains("--self-test") {
    // Pure validation path used by build/package checks. It never touches the
    // real hosts file or registers the daemon.
    do {
        let hostnames = try HostsHostnameValidator.validatedHostnames([
            "example.com",
            "www.example.com"
        ])
        let rendered = try HostsFileBlocks.apply(
            to: "127.0.0.1 localhost\n",
            hostnames: hostnames,
            sessionID: UUID()
        )
        guard rendered.contains(HostsFileBlocks.beginMarker),
              rendered.contains("127.0.0.1 example.com"),
              rendered.contains("::1 www.example.com")
        else {
            print("FocusBarHelper self-test failed")
            exit(1)
        }
        print("FocusBarHelper self-test ok")
        exit(0)
    } catch {
        print("FocusBarHelper self-test failed: \(error.localizedDescription)")
        exit(1)
    }
}

let logger = Logger(
    subsystem: SystemBlockingConstants.machServiceName,
    category: "lifecycle"
)
logger.info("Starting FocusBarHelper")

let service = HostsBlockingService()
let delegate = FocusBarHelperListenerDelegate(service: service)
let listener = NSXPCListener(machServiceName: SystemBlockingConstants.machServiceName)

// Clean up the hosts section on unregister/logout/reboot. A crash or SIGKILL
// skips this; the next helper launch removes any stale section.
signal(SIGTERM, SIG_IGN)
let terminationSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
terminationSource.setEventHandler {
    logger.info("Received SIGTERM; removing system block")
    service.cleanupForTermination()
    exit(0)
}
terminationSource.resume()

if let requirement = HelperClientRequirement.make() {
    listener.setConnectionCodeSigningRequirement(requirement)
} else {
    logger.error("Could not build a client code-signing requirement")
}

listener.delegate = delegate
listener.activate()

RunLoop.current.run()
