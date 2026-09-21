import SwiftUI

struct BatteryRing: View {
    let device: Device
    let symbol: String
    var size: CGFloat = 48

    private var lineWidth: CGFloat { size * 0.09 }

    var body: some View {
        ZStack {
            if let percent = device.percent {
                let progress = CGFloat(min(100, max(0, percent))) / 100
                ZStack {
                    Circle().stroke(Color.primary.opacity(0.08), lineWidth: lineWidth)
                    if progress == 1 {
                        // A closed circle has no end caps meeting at 100%.
                        Circle().stroke(Color.green, lineWidth: lineWidth)
                    } else if progress > 0 {
                        Circle().trim(from: 0, to: progress)
                            .stroke(Color.green, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                }
                .padding(lineWidth / 2)
            }
            Image(systemName: symbol)
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.46, height: size * 0.46)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
