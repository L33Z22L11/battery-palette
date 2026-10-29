import Foundation
import Darwin
import os

struct RegistrationCommandResult {
    let status: Int32
    let output: String
}

enum WidgetRegistrationRepair {
    enum Outcome: Equatable { case registered, repaired, disabled, failed }
    typealias Runner = (String, [String]) -> RegistrationCommandResult
    static let pluginKit = "/usr/bin/pluginkit"
    static let launchServices = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

    static func state(_ output: String, extensionURL: URL) -> Outcome? {
        let expected = extensionURL.resolvingSymlinksInPath().path
        for line in output.components(separatedBy: .newlines) {
            let columns = line.components(separatedBy: "\t")
            guard columns.count >= 2, let path = columns.last,
                  URL(fileURLWithPath: path.trimmingCharacters(in: .whitespaces)).resolvingSymlinksInPath().path == expected else { continue }
            return line.trimmingCharacters(in: .whitespaces).hasPrefix("-") ? .disabled : .registered
        }
        return nil
    }

    static func repair(appURL: URL, identifier: String, run: Runner) -> Outcome {
        let ext = appURL.appendingPathComponent("Contents/PlugIns/BatteryPaletteWidget.appex")
        let query = ["-m", "-A", "-D", "-v", "-i", identifier]
        let before = run(pluginKit, query)
        guard before.status == 0 else { return .failed }
        if let current = state(before.output, extensionURL: ext) { return current }
        guard run(launchServices, ["-f", appURL.path]).status == 0,
              run(pluginKit, ["-a", ext.path]).status == 0 else { return .failed }
        let after = run(pluginKit, query)
        guard after.status == 0, state(after.output, extensionURL: ext) == .registered else { return .failed }
        return .repaired
    }

    static func run(_ executable: String, _ arguments: [String]) -> RegistrationCommandResult {
        let process = Process()
        let pipe = Pipe()
        let finished = DispatchSemaphore(value: 0)
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { _ in finished.signal() }
        do { try process.run() } catch { return .init(status: -1, output: "") }
        if finished.wait(timeout: .now() + 5) == .timedOut {
            process.terminate()
            if finished.wait(timeout: .now() + 1) == .timedOut, process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
            return .init(status: -1, output: "")
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return .init(status: process.terminationStatus, output: String(decoding: data, as: UTF8.self))
    }
}

// Called only at launch and wake; registration commands run off-thread.
final class WidgetRegistrationHealth {
    private let logger = Logger(subsystem: "local.battery-palette", category: "widget-registration")
    private var checking = false
    private var lastCheck = -Double.infinity
    var onRepair: (() -> Void)?

    func check(afterWake: Bool = false) {
        let now = ProcessInfo.processInfo.systemUptime
        guard !checking, now - lastCheck >= 5 else { return }
        let appURL = Bundle.main.bundleURL
        let ext = appURL.appendingPathComponent("Contents/PlugIns/BatteryPaletteWidget.appex")
        guard FileManager.default.fileExists(atPath: ext.path) else { return }
        checking = true
        lastCheck = now
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + (afterWake ? 3 : 0)) { [weak self] in
            let outcome = WidgetRegistrationRepair.repair(appURL: appURL, identifier: "local.battery-palette.widget", run: WidgetRegistrationRepair.run)
            DispatchQueue.main.async {
                guard let self else { return }
                self.checking = false
                switch outcome {
                case .repaired:
                    self.logger.notice("Restored missing widget registration; requesting timeline reload")
                    self.onRepair?()
                case .failed:
                    self.logger.error("Widget registration check or repair failed; retry at the next launch or wake")
                case .registered:
                    self.logger.info("Widget registration is healthy")
                case .disabled:
                    self.logger.info("Widget was disabled; preserving user choice")
                }
            }
        }
    }
}
