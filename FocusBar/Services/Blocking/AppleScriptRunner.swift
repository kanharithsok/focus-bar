import Foundation

enum AppleScriptError: Error, Equatable {
    case permissionDenied
    case timedOut
    case executionFailed(String)
    case launchFailed(String)

    var isPermissionDenied: Bool {
        if case .permissionDenied = self { return true }
        return false
    }

    var isTimeout: Bool {
        if case .timedOut = self { return true }
        return false
    }
}

/// Runs static AppleScript via `/usr/bin/osascript` off the main thread with a
/// hard timeout. Scripts and arguments are passed as an argument array; no shell
/// interpolation is used.
actor AppleScriptRunner {
    func run(
        script: String,
        arguments: [String] = [],
        timeout: TimeInterval = 2.5
    ) async -> Result<String, AppleScriptError> {
        let outcome = await Self.execute(
            script: script,
            arguments: arguments,
            timeout: timeout
        )

        if outcome.timedOut {
            return .failure(.timedOut)
        }
        if outcome.launchFailed {
            return .failure(.launchFailed(outcome.stderr))
        }

        let stderr = outcome.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if outcome.terminationStatus != 0 {
            if Self.isPermissionError(stderr) {
                return .failure(.permissionDenied)
            }
            let message = stderr.isEmpty
                ? "osascript exited with status \(outcome.terminationStatus)"
                : stderr
            return .failure(.executionFailed(message))
        }

        return .success(outcome.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func isPermissionError(_ stderr: String) -> Bool {
        let lower = stderr.lowercased()
        return lower.contains("-1743")
            || lower.contains("erraeeventnotpermitted")
            || lower.contains("not authorized to send apple events")
            || lower.contains("not allowed to send apple events")
            || lower.contains("not permitted to send apple events")
    }

    private struct ProcessOutcome: Sendable {
        var stdout: String
        var stderr: String
        var terminationStatus: Int32
        var timedOut: Bool
        var launchFailed: Bool
    }

    private final class ProcessState: @unchecked Sendable {
        private let lock = NSLock()
        private var timedOut = false

        func markTimedOut() {
            lock.lock()
            timedOut = true
            lock.unlock()
        }

        var didTimeOut: Bool {
            lock.lock()
            defer { lock.unlock() }
            return timedOut
        }
    }

    private static func execute(
        script: String,
        arguments: [String],
        timeout: TimeInterval
    ) async -> ProcessOutcome {
        await withCheckedContinuation { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script] + arguments
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let state = ProcessState()
            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
            timer.schedule(deadline: .now() + timeout)
            timer.setEventHandler {
                guard process.isRunning else { return }
                state.markTimedOut()
                process.terminate()
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5) {
                    if process.isRunning {
                        kill(process.processIdentifier, SIGKILL)
                    }
                }
            }

            process.terminationHandler = { terminatedProcess in
                timer.cancel()
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let outcome = ProcessOutcome(
                    stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                    stderr: String(data: stderrData, encoding: .utf8) ?? "",
                    terminationStatus: terminatedProcess.terminationStatus,
                    timedOut: state.didTimeOut,
                    launchFailed: false
                )
                continuation.resume(returning: outcome)
            }

            timer.resume()
            do {
                try process.run()
            } catch {
                timer.cancel()
                continuation.resume(
                    returning: ProcessOutcome(
                        stdout: "",
                        stderr: error.localizedDescription,
                        terminationStatus: -1,
                        timedOut: false,
                        launchFailed: true
                    )
                )
            }
        }
    }
}
