import AppKit

// All status colors are system semantic colors; normal keeps the menu bar's
// template-image contrast for light/dark wallpapers.
enum BatteryStatusTone: String {
    case normal, lowBattery, lowPower, game, charging

    static func resolve(percent: Int?, charging: Bool, lowPower: Bool, game: Bool) -> Self {
        if let percent, percent <= 20, !charging { return .lowBattery }
        if lowPower { return .lowPower }
        if game { return .game }
        if charging { return .charging }
        return .normal
    }

    var color: NSColor? {
        switch self {
        case .normal: return nil
        case .lowBattery: return .systemRed
        case .lowPower: return .systemYellow
        case .game: return .systemBlue
        case .charging: return .systemGreen
        }
    }
    var label: String {
        switch self {
        case .normal: return "正常供电"
        case .lowBattery: return "电量偏低"
        case .lowPower: return "低电量模式"
        case .game: return "游戏模式"
        case .charging: return "正在充电"
        }
    }
}

enum StatusIconRenderer {
    static func image(percent: Int?, tone: BatteryStatusTone, appearance: NSAppearance, showPercentage: Bool = true) -> NSImage {
        let template = tone == .normal
        let image = NSImage(size: NSSize(width: 22, height: 22), flipped: false) { bounds in
            // Resolve dynamic colors using the menu bar button's appearance,
            // which can differ from the app's appearance because of wallpaper.
            appearance.performAsCurrentDrawingAppearance {
                let foreground: NSColor = template ? .black : .labelColor
                let progress = tone.color ?? foreground
                let track = NSBezierPath(ovalIn: bounds.insetBy(dx: 1.5, dy: 1.5))
                track.lineWidth = 1.5
                foreground.withAlphaComponent(0.18).setStroke()
                track.stroke()
                if let percent, percent > 0 {
                    progress.setStroke()
                    if percent >= 100 {
                        track.stroke()
                    } else {
                        let arc = NSBezierPath()
                        arc.lineWidth = 1.5
                        arc.lineCapStyle = .round
                        arc.appendArc(withCenter: NSPoint(x: 11, y: 11), radius: 9.5,
                                      startAngle: 90, endAngle: 90 - CGFloat(percent) * 3.6, clockwise: true)
                        arc.stroke()
                    }
                }
                let label = showPercentage ? (percent.map(String.init) ?? "–") : ""
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: percent == 100 ? 7.5 : 9),
                    .foregroundColor: foreground
                ]
                let size = (label as NSString).size(withAttributes: attributes)
                (label as NSString).draw(at: NSPoint(x: (22 - size.width) / 2, y: (22 - size.height) / 2), withAttributes: attributes)
            }
            return true
        }
        // A template is a monochrome mask. Colored rings need an original image
        // so AppKit does not recolor the text and progress arc together.
        image.isTemplate = template
        image.accessibilityDescription = percent.map { "MacBook 电量 \($0)%" } ?? "电量暂不可用"
        return image
    }
}

final class GameModeReader {
    private(set) var isEnabled: Bool?
    var onChange: (() -> Void)?
    private var checking = false
    private var lastCheck = Date.distantPast

    static func parse(_ text: String) -> Bool? {
        let plain = text.replacingOccurrences(of: "\u{001B}\\[[0-9;]*m", with: "", options: .regularExpression)
        for line in plain.components(separatedBy: .newlines) {
            switch line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "game mode is on.": return true
            case "game mode is off.": return false
            default: continue
            }
        }
        return nil
    }

    func refresh() {
        // Reuse the host's existing refresh/activation events, with no extra timer.
        guard !checking, Date().timeIntervalSince(lastCheck) >= 5 else { return }
        lastCheck = Date()
        let path = "/Applications/Xcode.app/Contents/Developer/usr/bin/gamepolicyctl"
        guard FileManager.default.isExecutableFile(atPath: path) else {
            if isEnabled != nil { isEnabled = nil; onChange?() }
            return
        }
        checking = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let process = Process()
            let output = Pipe()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = ["game-mode", "status"]
            process.environment = ProcessInfo.processInfo.environment.merging(["LC_ALL": "C", "NO_COLOR": "1"]) { _, new in new }
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            var result: Bool?
            do {
                try process.run()
                let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 3, execute: timeout)
                let data = output.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                timeout.cancel()
                if process.terminationStatus == 0, let text = String(data: data, encoding: .utf8) { result = Self.parse(text) }
            } catch { result = nil }
            let value = result
            DispatchQueue.main.async {
                guard let self else { return }
                self.checking = false
                let changed = self.isEnabled != value
                self.isEnabled = value
                if changed { self.onChange?() }
            }
        }
    }
}
