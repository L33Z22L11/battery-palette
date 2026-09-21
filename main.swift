import AppKit
import SwiftUI
import IOKit.ps
import Darwin
import WidgetKit
import ServiceManagement

final class BatteryModel: ObservableObject {
    @Published var devices: [Device] = []
    @Published var updated: Date? = nil
    @Published var failed = false
    @Published var overrides: [String: String] = UserDefaults.standard.dictionary(forKey: "icons") as? [String: String] ?? [:]
    var display = BatteryDisplayOptions()
    var timer: Timer?
    var onRefresh: (() -> Void)?
    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.refresh() }
        timer?.tolerance = 5
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(woke), name: NSWorkspace.didWakeNotification, object: nil)
    }
    @objc func woke() { refresh() }
    func refresh() {
        if let result = readDevices() { devices = result; updated = Date(); failed = false }
        else { failed = true; devices = [] }
        publishSnapshot()
        onRefresh?()
    }
    private var lastPublished: [Device] = []
    private var lastPublishedIcons: [String: String] = [:]
    private var lastReload = Date.distantPast
    func publishSnapshot(forceReload: Bool = false) {
        let snapshot = BatterySnapshot(date: Date(), devices: devices, icons: overrides, display: display)
        do {
            try SnapshotStore.write(snapshot)
            let changed = devices != lastPublished || overrides != lastPublishedIcons
            if forceReload || changed || Date().timeIntervalSince(lastReload) > 15 * 60 {
                WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
                lastReload = Date()
                lastPublished = devices
                lastPublishedIcons = overrides
            }
        } catch { NSLog("Widget snapshot: %@", error.localizedDescription) }
    }

    func icon(_ d: Device) -> String { overrides[d.id] ?? d.defaultIcon }
    func setIcon(_ d: Device, _ symbol: String?) {
        overrides[d.id] = symbol
        UserDefaults.standard.set(overrides, forKey: "icons")
        publishSnapshot(forceReload: true)
    }
}

enum RestingMode { case hidden, desktop }
enum PresentationPreset: String, CaseIterable, Identifiable {
    case widgetOnly, menuBar, desktop
    var id: String { rawValue }
    var title: String {
        switch self {
        case .widgetOnly: return "仅组件"
        case .menuBar: return "菜单栏"
        case .desktop: return "桌面浮窗"
        }
    }
}

final class PresentationPreferences: ObservableObject {
    @Published var preset: PresentationPreset { didSet { save() } }
    @Published var showPercentage: Bool { didSet { save() } }
    @Published var showDeviceNames: Bool { didSet { save() } }
    @Published var loginEnabled = false
    @Published var loginNeedsApproval = false
    @Published var loginError: String?
    var onChange: (() -> Void)?
    var restingMode: RestingMode { preset == .desktop ? .desktop : .hidden }
    var showMenuBar: Bool { preset != .widgetOnly }
    var display: BatteryDisplayOptions { BatteryDisplayOptions(showPercentage: showPercentage, showDeviceNames: showDeviceNames) }
    init() {
        let d = UserDefaults.standard
        if let value = d.string(forKey: "presentationPreset"), let saved = PresentationPreset(rawValue: value) {
            preset = saved
        } else if d.string(forKey: "restingMode") == "desktop" { preset = .desktop }
        else { preset = (d.object(forKey: "showMenuBar") as? Bool ?? true) ? .menuBar : .widgetOnly }
        showPercentage = d.object(forKey: "showPercentage") as? Bool ?? true
        showDeviceNames = d.object(forKey: "showDeviceNames") as? Bool ?? true
        refreshLoginStatus()
    }
    private func save() {
        let d = UserDefaults.standard
        d.set(preset.rawValue, forKey: "presentationPreset")
        d.set(showPercentage, forKey: "showPercentage")
        d.set(showDeviceNames, forKey: "showDeviceNames")
        onChange?()
    }
    func refreshLoginStatus() {
        let status = SMAppService.mainApp.status
        loginEnabled = status == .enabled || status == .requiresApproval
        loginNeedsApproval = status == .requiresApproval
    }
    func setLoginEnabled(_ enabled: Bool) {
        loginError = nil
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch { loginError = "无法更改开机自启：\(error.localizedDescription)" }
        refreshLoginStatus()
    }
}

struct PaletteSettingsView: View {
    @ObservedObject var preferences: PresentationPreferences
    var body: some View {
        Form {
            Section("显示方式") {
                Picker("预设", selection: $preferences.preset) {
                    ForEach(PresentationPreset.allCases) { preset in Text(preset.title).tag(preset) }
                }.pickerStyle(.segmented)
                Toggle("显示电量百分比", isOn: $preferences.showPercentage)
                Toggle("显示设备名称", isOn: $preferences.showDeviceNames)
            }
            Section("启动") {
                Toggle("开机自启", isOn: Binding(get: { preferences.loginEnabled }, set: { preferences.setLoginEnabled($0) }))
                if preferences.loginNeedsApproval {
                    Button("在系统设置中允许开机自启") { SMAppService.openSystemSettingsLoginItems() }
                }
                if let error = preferences.loginError { Text(error).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .frame(width: 460, height: 300)
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)) { _ in
            preferences.refreshLoginStatus()
        }
    }
}

struct BatteryView: View {
    @ObservedObject var model: BatteryModel
    @ObservedObject var preferences: PresentationPreferences
    let settings: () -> Void
    let dismiss: () -> Void
    private var panelActions: some View {
        Group {
            Button("设置…", action: settings)
            Button("收起面板", action: dismiss)
        }
    }
    var body: some View {
        VStack(spacing: 14) {
            if model.devices.isEmpty {
                Label(model.failed ? "电量暂不可用" : "暂无设备", systemImage: "battery.0percent")
                    .font(.system(size: 13))
            }
            ForEach(model.devices) { d in
                HStack(spacing: 14) {
                    BatteryRing(device: d, symbol: model.icon(d), size: 56)
                    if preferences.showDeviceNames { Text(d.name).font(.system(size: 13)).lineLimit(1) }
                    Spacer(minLength: 4)
                    if d.charging { Image(systemName: "bolt.fill").font(.system(size: 11)) }
                    if preferences.showPercentage { Text(d.percent.map { "\($0)%" } ?? "—").font(.system(size: 18)) }
                }
                .contentShape(Rectangle())
                .contextMenu {
                    ForEach(iconChoices, id: \.1) { title, symbol in
                        Button { model.setIcon(d, symbol) } label: {
                            Label(title + (model.icon(d) == symbol ? " ✓" : ""), systemImage: symbol)
                        }
                    }
                    Button("恢复默认图标") { model.setIcon(d, nil) }
                    Divider()
                    panelActions
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(20)
        .frame(width: 350)
        .contentShape(Rectangle())
        .contextMenu { panelActions }
    }
}

final class DesktopPanel: NSPanel {
    var onDismiss: (() -> Void)?
    var onInteract: (() -> Void)?
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown || event.type == .rightMouseDown {
            onInteract?()
        }
        // Preserve normal click, drag and context-menu handling.
        super.sendEvent(event)
    }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onDismiss?() }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    let model = BatteryModel()
    let preferences = PresentationPreferences()
    let gameMode = GameModeReader()
    var panel: DesktopPanel!
    var glassSurface: NSView?
    var status: NSStatusItem?
    var statusAppearanceObservation: NSKeyValueObservation?
    var settingsWindow: NSWindow?
    var isSummoned = false
    var outsideMonitor: Any?
    var workspaceObserver: NSObjectProtocol?
    var pendingSummon = false
    var widgetAnchor: NSPoint?
    var desktopTopLeft: NSPoint?

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = DesktopPanel(contentRect: NSRect(x: 0, y: 0, width: 350, height: 350), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.delegate = self
        panel.onDismiss = { [weak self] in self?.settlePanel() }
        panel.onInteract = { [weak self] in
            guard let self, !self.isSummoned else { return }
            self.summonPanel()
        }
        let hosting = NSHostingView(rootView: BatteryView(model: model, preferences: preferences,
            settings: { [weak self] in self?.showSettings() },
            dismiss: { [weak self] in self?.settlePanel() }))
        let surface: NSView
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.style = .clear
            glass.cornerRadius = 22
            glass.clipsToBounds = true
            glass.contentView = hosting
            glassSurface = glass
            surface = glass
        } else {
            let material = NSVisualEffectView()
            material.material = .hudWindow
            material.blendingMode = .behindWindow
            material.state = .active
            hosting.frame = material.bounds
            hosting.autoresizingMask = [.width, .height]
            material.addSubview(hosting)
            surface = material
        }
        // The glass itself owns the window contour; no transparent outer shell.
        panel.contentView = surface
        // Save desktop placement explicitly; tray placement must not overwrite it.
        model.onRefresh = { [weak self] in
            DispatchQueue.main.async { self?.resizePanel(); self?.updateStatusImage(); self?.gameMode.refresh() }
        }
        let restored = panel.setFrameUsingName("BatteryPalettePanel")
        if restored, UserDefaults.standard.integer(forKey: "panelChromeVersion") < 1 {
            // Keep the visible card in place when removing the old 8-point shell.
            panel.setFrame(panel.frame.insetBy(dx: 8, dy: 8), display: false)
        }
        UserDefaults.standard.set(1, forKey: "panelChromeVersion")
        resizePanel()
        if !restored { positionPanel() }
        clampPanelToScreen()
        desktopTopLeft = NSPoint(x: panel.frame.minX, y: panel.frame.maxY)
        preferences.onChange = { [weak self] in
            guard let self else { return }
            self.model.display = self.preferences.display
            self.model.publishSnapshot(forceReload: true)
            self.updateStatusItem()
            self.updateStatusImage()
            self.resizePanel()
            self.settlePanel()
        }
        model.display = preferences.display
        model.publishSnapshot(forceReload: true)
        gameMode.onChange = { [weak self] in self?.updateStatusImage() }
        NotificationCenter.default.addObserver(self, selector: #selector(powerModeChanged), name: .NSProcessInfoPowerStateDidChange, object: nil)
        updateStatusItem()
        gameMode.refresh()
        installAppMenu()
        // These monitors need no event tap or Accessibility permission.
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.isSummoned == true { self?.settlePanel() }
        }
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            self?.gameMode.refresh()
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
                  self?.isSummoned == true else { return }
            self?.settlePanel()
        }
        let pendingAnchor = widgetAnchor
        settlePanel()
        if pendingSummon || CommandLine.arguments.contains("--preview") { presentPanel(near: pendingAnchor) }
    }

    func installAppMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "设置…", action: #selector(showSettings), keyEquivalent: ",")
        appMenu.addItem(withTitle: "完全退出（停止后台更新）", action: #selector(quit), keyEquivalent: "q")
        for item in appMenu.items { item.target = self }
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)
        NSApp.mainMenu = mainMenu
    }

    func updateStatusItem() {
        if !preferences.showMenuBar {
            statusAppearanceObservation = nil
            if let status { NSStatusBar.system.removeStatusItem(status) }
            status = nil
            return
        }
        guard status == nil else { return }
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusAppearanceObservation = status?.button?.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.updateStatusImage() }
        }
        updateStatusImage()
        status?.button?.target = self
        status?.button?.action = #selector(statusClicked)
        status?.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    func updateStatusImage() {
        guard let button = status?.button else { return }
        let battery = model.devices.first(where: { $0.id == "internal" })
        let percent = battery?.percent
        let tone = BatteryStatusTone.resolve(percent: percent, charging: battery?.charging ?? false,
                                             lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled,
                                             game: gameMode.isEnabled == true)
        button.contentTintColor = nil
        button.image = StatusIconRenderer.image(percent: percent, tone: tone, appearance: button.effectiveAppearance, showPercentage: preferences.showPercentage)
        // Let AppKit provide its standard selected-menu contrast while tracking.
        button.alternateImage = StatusIconRenderer.image(percent: percent, tone: .normal, appearance: button.effectiveAppearance, showPercentage: preferences.showPercentage)
        button.toolTip = "MacBook \(percent.map { "\($0)%" } ?? "—") · \(tone.label)\n左键唤出／收起，右键设置显示方式"
    }

    @objc func powerModeChanged() { updateStatusImage() }

    func menuDidClose(_ menu: NSMenu) {
        // Detach after native tracking completes so the next left click still
        // invokes our panel action rather than reopening the menu.
        if status?.menu === menu { status?.menu = nil }
    }

    @objc func selectWidgetOnly() { preferences.preset = .widgetOnly; settlePanel() }

    @objc func selectDesktopMode() {
        preferences.preset = .desktop
        settlePanel()
    }
    @objc func selectTemporaryMode() {
        preferences.preset = .menuBar
        settlePanel()
    }

    @objc func statusClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            let widgetOnly = menu.addItem(withTitle: "仅组件", action: #selector(selectWidgetOnly), keyEquivalent: "")
            widgetOnly.state = preferences.preset == .widgetOnly ? .on : .off
            let desktop = menu.addItem(withTitle: "桌面浮窗", action: #selector(selectDesktopMode), keyEquivalent: "")
            desktop.state = preferences.restingMode == .desktop ? .on : .off
            let temporary = menu.addItem(withTitle: "菜单栏", action: #selector(selectTemporaryMode), keyEquivalent: "")
            temporary.state = preferences.preset == .menuBar ? .on : .off
            menu.addItem(.separator())
            menu.addItem(withTitle: "刷新电量", action: #selector(refresh), keyEquivalent: "")
            menu.addItem(withTitle: "设置…", action: #selector(showSettings), keyEquivalent: ",")
            menu.addItem(.separator())
            menu.addItem(withTitle: "完全退出（停止后台更新）", action: #selector(quit), keyEquivalent: "q")
            for item in menu.items { item.target = self }
            menu.delegate = self
            status?.menu = menu
            status?.button?.performClick(nil)
        } else if isSummoned {
            settlePanel()
        } else {
            summonPanel()
        }
    }

    func updateGlassStyle() {
        if #available(macOS 26.0, *), let glass = glassSurface as? NSGlassEffectView {
            let style: NSGlassEffectView.Style = isSummoned ? .regular : .clear
            guard glass.style != style else { return }
            glass.style = style
            panel.invalidateShadow()
        }
    }

    @objc func summonPanel() { presentPanel(near: nil) }

    func presentPanel(near point: NSPoint?) {
        widgetAnchor = point
        guard panel != nil else { pendingSummon = true; return }
        model.refresh()
        isSummoned = true
        updateGlassStyle()
        resizePanel()
        panel.isMovableByWindowBackground = preferences.restingMode == .desktop && widgetAnchor == nil
        if let widgetAnchor { positionNearWidgetClick(widgetAnchor) }
        else if preferences.restingMode == .hidden { positionBelowStatusItem() }
        else { clampPanelToScreen() }
        panel.level = .floating
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    @objc func settlePanel() {
        guard panel != nil else { return }
        isSummoned = false
        updateGlassStyle()
        if preferences.restingMode == .hidden {
            panel.orderOut(nil)
        } else {
            panel.isMovableByWindowBackground = true
            if let desktopTopLeft { panel.setFrameTopLeftPoint(desktopTopLeft) }
            clampPanelToScreen()
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
            if panel.isKeyWindow { panel.resignKey() }
            panel.orderFrontRegardless()
        }
        widgetAnchor = nil
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        summonPanel()
        return false
    }
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "batterypalette" {
            if url.host == "settings" { showSettings() }
            else if url.host == "show" { presentPanel(near: NSEvent.mouseLocation) }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func windowDidResignKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === panel, isSummoned else { return }
        settlePanel()
    }
    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === panel,
              preferences.restingMode == .desktop, widgetAnchor == nil, desktopTopLeft != nil else { return }
        desktopTopLeft = NSPoint(x: panel.frame.minX, y: panel.frame.maxY)
        panel.saveFrame(usingName: "BatteryPalettePanel")
    }
    func resizePanel() {
        guard panel != nil else { return }
        let top = panel.frame.maxY
        let height = CGFloat(26 + max(1, model.devices.count) * 70)
        guard panel.frame.size != NSSize(width: 350, height: height) else { return }
        panel.setFrame(NSRect(x: panel.frame.minX, y: top - height, width: 350, height: height), display: true)
        if isSummoned {
            if let widgetAnchor { positionNearWidgetClick(widgetAnchor) }
            else if preferences.restingMode == .hidden { positionBelowStatusItem() }
        }
        panel.invalidateShadow()
    }
    func positionNearWidgetClick(_ point: NSPoint) {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main else { return }
        let bounds = screen.visibleFrame.insetBy(dx: 8, dy: 8)
        var frame = panel.frame
        // Prefer beside the clicked widget; flip left near the right screen edge.
        let x = point.x + 18 + frame.width <= bounds.maxX ? point.x + 18 : point.x - 18 - frame.width
        frame.origin.x = max(bounds.minX, min(x, bounds.maxX - frame.width))
        frame.origin.y = max(bounds.minY, min(point.y - frame.height / 2, bounds.maxY - frame.height))
        panel.setFrame(frame, display: true)
    }
    func positionBelowStatusItem() {
        let screen: NSScreen
        let anchor: NSRect?
        if let button = status?.button, let window = button.window,
           let itemScreen = window.screen, status?.isVisible == true {
            screen = itemScreen
            anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
        } else {
            // Widget-only use has no tray icon: use the current screen's top right.
            guard let activeScreen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main else { return }
            screen = activeScreen
            anchor = nil
        }
        let bounds = screen.visibleFrame.insetBy(dx: 8, dy: 8)
        var frame = panel.frame
        let x = anchor.map { $0.midX - frame.width / 2 } ?? (bounds.maxX - frame.width)
        let top = anchor.map { min($0.minY - 6, bounds.maxY) } ?? bounds.maxY
        frame.origin.x = max(bounds.minX, min(x, bounds.maxX - frame.width))
        frame.origin.y = max(bounds.minY, top - frame.height)
        panel.setFrame(frame, display: true)
    }
    func positionPanel() {
        if let screen = NSScreen.main { panel.setFrameTopLeftPoint(NSPoint(x: screen.visibleFrame.maxX - 390, y: screen.visibleFrame.maxY - 35)) }
    }
    func clampPanelToScreen() {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        var frame = panel.frame
        frame.origin.x = min(max(frame.minX, screen.visibleFrame.minX), screen.visibleFrame.maxX - frame.width)
        frame.origin.y = min(max(frame.minY, screen.visibleFrame.minY), screen.visibleFrame.maxY - frame.height)
        panel.setFrame(frame, display: true)
    }
    @objc func showSettings() {
        preferences.refreshLoginStatus()
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 300), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Battery Palette 设置"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: PaletteSettingsView(preferences: preferences))
            window.center()
            settingsWindow = window
        }
        settlePanel()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func refresh() { model.refresh(); model.publishSnapshot(forceReload: true) }
    @objc func resetPosition() { positionPanel(); summonPanel() }
    @objc func quit() { NSApp.terminate(nil) }
}
if CommandLine.arguments.contains("--widget-dump") {
    print(SnapshotStore.widgetSnapshot())
} else if CommandLine.arguments.contains("--dump") {
    if let devices = readDevices(), let data = try? JSONEncoder().encode(devices), let json = String(data: data, encoding: .utf8) { print(json) } else { fputs("Unable to read power sources\n", stderr); exit(1) }
} else {
    let instanceLock = Darwin.open("/tmp/local.battery-palette.\(getuid()).lock", O_CREAT | O_RDWR, 0o600)
    guard instanceLock >= 0, flock(instanceLock, LOCK_EX | LOCK_NB) == 0 else {
        if !CommandLine.arguments.contains("--background") { NSWorkspace.shared.open(URL(string: "batterypalette://show")!) }
        exit(0)
    }
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
