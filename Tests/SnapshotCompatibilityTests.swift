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
        print("Snapshot compatibility and display settings round-trip passed")
    }
}
