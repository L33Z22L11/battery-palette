import WidgetKit
import SwiftUI

struct BatteryEntry: TimelineEntry {
    let date: Date
    let snapshot: BatterySnapshot
}
struct BatteryProvider: TimelineProvider {
    func placeholder(in context: Context) -> BatteryEntry {
        let names = [("笔记本电脑", "laptopcomputer"), ("无线键盘", "keyboard"), ("无线鼠标", "computermouse"), ("遥控器", "appletvremote.gen4")]
        let samples = names.enumerated().map { i, n in
            Device(id: "sample-\(i)", name: n.0, percent: [100, 43, 64, 63][i], charging: false, category: "", defaultIcon: n.1)
        }
        return BatteryEntry(date: Date(), snapshot: BatterySnapshot(date: Date(), devices: samples, icons: [:]))
    }
    func getSnapshot(in context: Context, completion: @escaping (BatteryEntry) -> Void) {
        let snapshot = SnapshotStore.widgetSnapshot()
        completion(BatteryEntry(date: Date(), snapshot: snapshot))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<BatteryEntry>) -> Void) {
        let now = Date()
        let snapshot = SnapshotStore.widgetSnapshot()
        let entry = BatteryEntry(date: now, snapshot: snapshot)
        // Do not display old battery values indefinitely if the host is stopped.
        let expiry = BatteryEntry(date: max(now.addingTimeInterval(1), snapshot.date.addingTimeInterval(20 * 60)), snapshot: BatterySnapshot(date: now, devices: [], icons: snapshot.icons, display: snapshot.display))
        completion(Timeline(entries: [entry, expiry], policy: .after(now.addingTimeInterval(5 * 60))))
    }
}
struct BatteryWidgetView: View {
    let entry: BatteryEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: family == .systemLarge ? .topLeading : .center)
        .widgetURL(URL(string: "batterypalette://show?source=widget"))
        .padding(family == .systemSmall ? 10 : 16)
        .containerBackground(for: .widget) { Color.clear }
    }
    @ViewBuilder var content: some View {
        Group {
            if entry.snapshot.devices.isEmpty {
                Image(systemName: "battery.0percent").font(.largeTitle)
                    .accessibilityLabel("电量暂不可用，请打开 BatteryPalette")
            } else if family == .systemLarge {
                VStack(spacing: 8) {
                    ForEach(Array(entry.snapshot.devices.prefix(6))) { d in
                        HStack(spacing: 12) {
                            BatteryRing(device: d, symbol: icon(d), size: 44)
                            if entry.snapshot.displayOptions.showDeviceNames { Text(d.name).font(.system(size: 13)).lineLimit(1) }
                            Spacer(minLength: 2)
                            percentage(d, fontSize: 17)
                        }.accessibilityElement(children: .combine)
                    }
                }
            } else if family == .systemSmall {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(Array(entry.snapshot.devices.prefix(4))) { d in tile(d, small: true) }
                }
            } else {
                HStack(alignment: .center, spacing: 8) {
                    ForEach(Array(entry.snapshot.devices.prefix(4))) { d in
                        tile(d, small: false).frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
    func icon(_ d: Device) -> String { entry.snapshot.icons[d.id] ?? d.defaultIcon }
    func percentage(_ d: Device, fontSize: CGFloat) -> some View {
        HStack(spacing: 2) {
            if d.charging { Image(systemName: "bolt.fill").font(.system(size: 9)) }
            if entry.snapshot.displayOptions.showPercentage {
                Text(d.percent.map { "\($0)%" } ?? "—").font(.system(size: fontSize))
            }
        }
    }
    func tile(_ d: Device, small: Bool) -> some View {
        VStack(spacing: small ? 2 : 7) {
            BatteryRing(device: d, symbol: icon(d), size: small ? 38 : 60)
            if entry.snapshot.displayOptions.showPercentage || d.charging { percentage(d, fontSize: small ? 12 : 19) }
            if entry.snapshot.displayOptions.showDeviceNames {
                Text(d.name).font(.system(size: small ? 9 : 10))
                    .lineLimit(1).minimumScaleFactor(0.75)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
@main
struct BatteryPaletteWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: widgetKind, provider: BatteryProvider()) { entry in
            BatteryWidgetView(entry: entry)
        }
        .configurationDisplayName("Battery Palette")
        .description("设备图标与电量")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .containerBackgroundRemovable(true)
        .contentMarginsDisabled()
    }
}
