import Foundation

@main struct SnapshotCompatibilityTests {
    static func main() throws {
        let old = Data(#"{"date":0,"devices":[],"icons":{}}"#.utf8)
        let snapshot = try JSONDecoder().decode(BatterySnapshot.self, from: old)
        precondition(snapshot.displayOptions.showPercentage && snapshot.displayOptions.showDeviceNames)
        let partial = try JSONDecoder().decode(BatteryDisplayOptions.self, from: Data(#"{"showPercentage":false}"#.utf8))
        precondition(!partial.showPercentage && partial.showDeviceNames)
        let changed = BatterySnapshot(date: Date(), devices: [], icons: [:], display: BatteryDisplayOptions(showPercentage: false, showDeviceNames: false))
        let roundTrip = try JSONDecoder().decode(BatterySnapshot.self, from: JSONEncoder().encode(changed))
        precondition(roundTrip.displayOptions == changed.displayOptions)
        func device(_ id: String, _ value: Int?) -> Device {
            Device(id: id, name: id, percent: value, charging: false, category: "", defaultIcon: "keyboard")
        }
        let ordered = devicesByLowestBattery([device("unknown", nil), device("full", 100), device("low-a", 10), device("zero", 0), device("low-b", 10)])
        precondition(ordered.map(\.id) == ["zero", "low-a", "low-b", "full", "unknown"])
        print("Snapshot compatibility and display settings round-trip passed")
    }
}
