import AppKit

@main struct StatusIconAppearanceCheck {
    static func main() throws {
        let tones: [BatteryStatusTone] = [.charging, .lowBattery, .lowPower, .game]
        let appearances: [NSAppearance.Name] = [.aqua, .darkAqua, .vibrantLight, .vibrantDark]
        let sheet = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 480, pixelsHigh: 280,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                     isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: sheet)
        for (row, name) in appearances.enumerated() {
            let appearance = NSAppearance(named: name)!
            let dark = row % 2 == 1
            let y = CGFloat(3 - row) * 70
            (dark ? NSColor(white: 0.12, alpha: 1) : NSColor(white: 0.94, alpha: 1)).setFill()
            NSRect(x: 0, y: y, width: 480, height: 70).fill()
            (name.rawValue as NSString).draw(at: NSPoint(x: 8, y: y + 28), withAttributes: [
                .font: NSFont.systemFont(ofSize: 12), .foregroundColor: dark ? NSColor.white : NSColor.black
            ])
            for (column, tone) in tones.enumerated() {
                let icon = StatusIconRenderer.image(percent: 88, tone: tone, appearance: appearance)
                precondition(!icon.isTemplate)
                icon.draw(in: NSRect(x: 180 + column * 70, y: Int(y) + 13, width: 44, height: 44))
            }
            precondition(StatusIconRenderer.image(percent: 88, tone: .normal, appearance: appearance).isTemplate)
        }
        NSGraphicsContext.restoreGraphicsState()
        try sheet.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "/tmp/bp-status-appearances.png"))
        print("Rendered four status colors in Aqua, Dark Aqua, Vibrant Light and Vibrant Dark: /tmp/bp-status-appearances.png")
    }
}
