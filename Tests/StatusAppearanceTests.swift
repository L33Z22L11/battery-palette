import Foundation

@main struct StatusAppearanceTests {
    static func main() {
        func expect(_ condition: Bool, _ name: String) {
            precondition(condition, name)
        }
        expect(GameModeReader.parse("Game mode is \u{001B}[0;31moff\u{001B}[0;0m.\nGame mode enablement policy is currently automatic.") == false, "ANSI off")
        expect(GameModeReader.parse("Game mode is \u{001B}[0;32mon\u{001B}[0;0m.") == true, "ANSI on")
        expect(GameModeReader.parse("Game mode enablement policy is currently disabled. Game mode is forced always on.") == nil, "policy alone is not active status")
        expect(GameModeReader.parse("Error: unavailable") == nil, "unknown is not on")
        expect(BatteryStatusTone.resolve(percent: 20, charging: false, lowPower: true, game: true) == .lowBattery, "low charge wins when discharging")
        expect(BatteryStatusTone.resolve(percent: 20, charging: true, lowPower: false, game: false) == .charging, "charging low battery is green")
        expect(BatteryStatusTone.resolve(percent: 80, charging: true, lowPower: true, game: true) == .lowPower, "low power priority")
        expect(BatteryStatusTone.resolve(percent: 80, charging: true, lowPower: false, game: true) == .game, "game priority")
        expect(BatteryStatusTone.resolve(percent: 21, charging: false, lowPower: false, game: false) == .normal, "normal threshold")
        expect(BatteryStatusTone.resolve(percent: nil, charging: false, lowPower: false, game: false) == .normal, "unknown capacity is not low")
        print("10 status color and Game Mode parsing checks passed")
    }
}
