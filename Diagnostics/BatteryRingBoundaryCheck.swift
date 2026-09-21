import SwiftUI
@main struct RingCheckApp: App {
    let values = [0, 1, 50, 61, 99, 100]
    func row(size: CGFloat, dark: Bool) -> some View {
        HStack(spacing: 24) {
            ForEach(values, id: \.self) { value in
                VStack {
                    BatteryRing(device: Device(id: "test", name: "Test", percent: value, charging: false, category: "", defaultIcon: "keyboard"), symbol: value % 2 == 0 ? "keyboard" : "appletvremote.gen4", size: size)
                    Text("\(value)%")
                }.frame(width: 70)
            }
        }.padding(24).environment(\.colorScheme, dark ? .dark : .light)
            .background(dark ? Color.black : Color.white)
    }
    var body: some Scene {
        WindowGroup("Battery ring boundary check") {
            VStack(spacing:0) {
                row(size:56, dark:false)
                row(size:38, dark:false)
                row(size:56, dark:true)
            }.fixedSize()
        }
    }
}
