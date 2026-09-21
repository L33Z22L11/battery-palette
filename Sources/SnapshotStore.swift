import Foundation
import os

let widgetKind = "BatteryPaletteDevices"
let widgetBundleID = "local.battery-palette.widget"

struct BatteryDisplayOptions: Codable, Equatable {
    var showPercentage = true
    var showDeviceNames = true
    init(showPercentage: Bool = true, showDeviceNames: Bool = true) {
        self.showPercentage = showPercentage
        self.showDeviceNames = showDeviceNames
    }
    private enum CodingKeys: String, CodingKey { case showPercentage, showDeviceNames }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        showPercentage = try values.decodeIfPresent(Bool.self, forKey: .showPercentage) ?? true
        showDeviceNames = try values.decodeIfPresent(Bool.self, forKey: .showDeviceNames) ?? true
    }
}

struct BatterySnapshot: Codable {
    var date: Date
    var devices: [Device]
    var icons: [String: String]
    var display: BatteryDisplayOptions? = nil
    var displayOptions: BatteryDisplayOptions { display ?? BatteryDisplayOptions() }
}

enum SnapshotStore {
    private static let logger = Logger(subsystem: widgetBundleID, category: "battery-source")
    // The non-sandboxed host publishes only its own widget's battery snapshot.
    // The extension reads from its own sandbox; no extra filesystem entitlement.
    static var url: URL {
        if Bundle.main.bundleIdentifier == widgetBundleID {
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("batteries.json")
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/\(widgetBundleID)/Data/Documents/batteries.json")
    }
    static func write(_ snapshot: BatterySnapshot) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
    }
    static func read() -> BatterySnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(BatterySnapshot.self, from: data)
    }
    static func widgetSnapshot() -> BatterySnapshot {
        let saved = read()
        // Query IOKit on each timeline when accessible, so data doesn't freeze
        // when the menu-bar host is closed. Otherwise use a fresh host snapshot.
        if let live = readDevices(), !live.isEmpty {
            if Bundle.main.bundleIdentifier == widgetBundleID { logger.info("Live battery read: \(live.count) devices") }
            return BatterySnapshot(date: Date(), devices: live, icons: saved?.icons ?? [:], display: saved?.display)
        }
        if let saved, Date().timeIntervalSince(saved.date) < 20 * 60 {
            if Bundle.main.bundleIdentifier == widgetBundleID { logger.info("Using host battery snapshot: \(saved.devices.count) devices") }
            return saved
        }
        return BatterySnapshot(date: Date(), devices: [], icons: saved?.icons ?? [:], display: saved?.display)
    }
}
