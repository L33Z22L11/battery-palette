import Foundation
import IOKit.ps
import Darwin

struct Device: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let percent: Int?
    let charging: Bool
    let category: String
    let defaultIcon: String
}
let iconChoices: [(String, String)] = [("键盘", "keyboard"), ("鼠标", "computermouse"), ("遥控器", "appletvremote.gen4"), ("麦克风", "mic"), ("耳机", "headphones"), ("电脑", "laptopcomputer"), ("电池", "battery.100percent")]

func readDevices() -> [Device]? {
    typealias CopyAll = @convention(c) (Int32) -> Unmanaged<CFTypeRef>?
    guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY),
          let symbol = dlsym(handle, "IOPSCopyPowerSourcesByType") else { return nil }
    defer { dlclose(handle) }
    let copyAll = unsafeBitCast(symbol, to: CopyAll.self)
    guard let blob = copyAll(0)?.takeRetainedValue(),
          let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [AnyObject] else { return nil }
    return sources.compactMap { source in
        guard let d = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any] else { return nil }
        if let present = d["Is Present"] as? Bool, !present { return nil }
        let internalBattery = (d["Type"] as? String) == "InternalBattery"
        let originalName = d["Name"] as? String ?? "未知设备"
        let name = internalBattery ? "MacBook" : originalName
        let vendor = (d["Vendor ID"] as? NSNumber)?.intValue ?? 0
        let product = (d["Product ID"] as? NSNumber)?.intValue ?? 0
        let category = d["Accessory Category"] as? String ?? "Battery"
        let identifier = d["Accessory Identifier"] as? String ?? "\(vendor):\(product):\(originalName)"
        let icon: String
        if internalBattery { icon = "laptopcomputer" }
        else if vendor == 0x3434 && product == 0x0a38 { icon = "keyboard" }
        else if vendor == 0x2717 && product == 0x32b8 { icon = "appletvremote.gen4" }
        else if category == "Keyboard" { icon = "keyboard" }
        else if category == "Mouse" { icon = "computermouse" }
        else if category.lowercased().contains("head") { icon = "headphones" }
        else { icon = "battery.100percent" }
        var percent: Int? = nil
        if let current = d["Current Capacity"] as? NSNumber,
           let maximum = d["Max Capacity"] as? NSNumber, maximum.doubleValue > 0, current.doubleValue >= 0 {
            percent = min(100, max(0, Int((100 * current.doubleValue / maximum.doubleValue).rounded())))
        }
        return Device(id: internalBattery ? "internal" : identifier, name: name, percent: percent,
                      charging: d["Is Charging"] as? Bool ?? false, category: category, defaultIcon: icon)
    }.sorted { a, b in
        if a.id == "internal" && b.id != "internal" { return true }
        if b.id == "internal" { return false }
        return a.name.localizedStandardCompare(b.name) == .orderedAscending
    }
}
