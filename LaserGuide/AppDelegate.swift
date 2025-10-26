// AppDelegate.swift
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var screenManager = ScreenManager.shared
    private var calibrationWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var eventViewerWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 多重起動の防止（ただしRelaunchフラグがある場合はスキップ）
        let isRelaunch = UserDefaults.standard.bool(forKey: "IsRelaunching")
        if isRelaunch {
            // Relaunchフラグをクリア
            UserDefaults.standard.removeObject(forKey: "IsRelaunching")
            NSLog("LaserGuide: Relaunch detected, skipping duplicate check")
        } else if isAnotherInstanceRunning() {
            NSLog("LaserGuide: Another instance is already running. Terminating.")
            NSApp.terminate(nil)
            return
        }

        setupStatusBar()
        screenManager.setupOverlays()

        // グローバルマウス追跡を開始
        MouseTrackingManager.shared.startTracking()

        // Smart Edge Navigation を初期化
        EdgeNavigationManager.shared.startIfNeeded()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.title = "🔍"

            // マウス追跡への干渉を最小化するためのイベント処理設定
            button.sendAction(on: [.leftMouseUp])
        }

        let menu = NSMenu()

        // About項目
        let aboutItem = NSMenuItem(
            title: "About LaserGuide...",
            action: #selector(openAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        // キャリブレーション設定項目
        let calibrateItem = NSMenuItem(
            title: "Calibrate Physical Layout...",
            action: #selector(openCalibration),
            keyEquivalent: ""
        )
        calibrateItem.target = self
        menu.addItem(calibrateItem)

        menu.addItem(NSMenuItem.separator())

        // 自動起動の設定項目
        let autoLaunchItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleAutoLaunch),
            keyEquivalent: ""
        )
        autoLaunchItem.target = self
        autoLaunchItem.state = AutoLaunchManager.shared.isEnabled ? .on : .off
        menu.addItem(autoLaunchItem)

        menu.addItem(NSMenuItem.separator())

        // 物理レイアウト使用設定項目
        let usePhysicalLayoutItem = NSMenuItem(
            title: "Use Physical Layout",
            action: #selector(toggleUsePhysicalLayout),
            keyEquivalent: ""
        )
        usePhysicalLayoutItem.target = self
        let isEnabled = UserDefaults.standard.object(forKey: "UsePhysicalLayout") as? Bool ?? true
        usePhysicalLayoutItem.state = isEnabled ? .on : .off
        menu.addItem(usePhysicalLayoutItem)

        // Smart Edge Navigation 設定項目
        let smartEdgeItem = NSMenuItem(
            title: "Smart Edge Navigation",
            action: #selector(toggleSmartEdge),
            keyEquivalent: ""
        )
        smartEdgeItem.target = self
        smartEdgeItem.state = EdgeNavigationManager.shared.isSmartEdgeEnabled ? .on : .off
        menu.addItem(smartEdgeItem)

        // Event Viewer 項目
        let eventViewerItem = NSMenuItem(
            title: "Launch Event Viewer...",
            action: #selector(openEventViewer),
            keyEquivalent: ""
        )
        eventViewerItem.target = self
        menu.addItem(eventViewerItem)

        menu.addItem(NSMenuItem.separator())

        let relaunchItem = NSMenuItem(title: "Relaunch", action: #selector(relaunchApp), keyEquivalent: "r")
        relaunchItem.target = self
        menu.addItem(relaunchItem)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func openAbout() {
        // Close existing window if any
        aboutWindow?.close()
        aboutWindow = nil

        // Create new about window
        let contentView = AboutView()
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About LaserGuide"
        window.contentViewController = hostingController
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false

        // Activate the app to bring window to front
        NSApp.activate(ignoringOtherApps: true)

        aboutWindow = window
    }

    @objc private func openCalibration() {
        // Close existing window if any
        calibrationWindow?.close()
        calibrationWindow = nil

        // Create new calibration window
        let contentView = CalibrationView()
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 700),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Physical Display Layout Calibration"
        window.contentViewController = hostingController
        window.center()
        // window.level = .floating  // Removed: Allow window to be covered by other windows
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false

        // Activate the app to bring window to front
        NSApp.activate(ignoringOtherApps: true)

        calibrationWindow = window
    }

    @objc private func openEventViewer() {
        // Close existing window if any
        eventViewerWindow?.close()
        eventViewerWindow = nil

        // Create new event viewer window
        let contentView = EventViewerView()
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 900),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Edge Navigation Event Viewer"
        window.contentViewController = hostingController
        window.minSize = NSSize(width: 800, height: 600)
        window.setContentSize(NSSize(width: 1200, height: 900))
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false

        // Activate the app to bring window to front
        NSApp.activate(ignoringOtherApps: true)

        eventViewerWindow = window
    }

    @objc private func toggleAutoLaunch(_ sender: NSMenuItem) {
        let newState = AutoLaunchManager.shared.toggle()
        sender.state = newState ? .on : .off
    }

    @objc private func toggleUsePhysicalLayout(_ sender: NSMenuItem) {
        let newState = sender.state == .off
        sender.state = newState ? .on : .off

        UserDefaults.standard.set(newState, forKey: "UsePhysicalLayout")
        NotificationCenter.default.post(
            name: .usePhysicalLayoutDidChange,
            object: newState
        )

        NSLog("🔧 Use Physical Layout toggled: \(newState ? "ON" : "OFF")")
    }

    @objc private func toggleSmartEdge(_ sender: NSMenuItem) {
        let newState = sender.state == .off
        sender.state = newState ? .on : .off

        EdgeNavigationManager.shared.setSmartEdge(enabled: newState)

        NSLog("🧭 Smart Edge Navigation toggled: \(newState ? "ON" : "OFF")")

        // Check Accessibility permissions if enabling for the first time
        if newState && !EdgeNavigationManager.shared.checkAccessibilityPermissions() {
            EdgeNavigationManager.shared.requestAccessibilityPermissions()
        }
    }

    @objc private func screensDidChange() {
        screenManager.setupOverlays()
    }

    @objc private func relaunchApp() {
        let bundlePath = Bundle.main.bundlePath

        // Set relaunch flag so new instance can skip duplicate check
        UserDefaults.standard.set(true, forKey: "IsRelaunching")
        UserDefaults.standard.synchronize()

        // Launch new instance with -n flag to force new instance
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-n", bundlePath]

        do {
            try task.run()
            NSLog("🔄 Relaunching LaserGuide...")
            self.quitApp()
        } catch {
            NSLog("⚠️ Failed to relaunch: \(error)")
            // Clear flag if launch failed
            UserDefaults.standard.removeObject(forKey: "IsRelaunching")
        }
    }

    @objc private func quitApp() {
        // アプリ終了時にマウス追跡を停止
        MouseTrackingManager.shared.stopTracking()
        // Smart Edge Navigation を停止
        EdgeNavigationManager.shared.stop()
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Duplicate Launch Prevention

    private func isAnotherInstanceRunning() -> Bool {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return false
        }

        let runningApps = NSWorkspace.shared.runningApplications
        let instances = runningApps.filter { $0.bundleIdentifier == bundleIdentifier }

        // 自分自身を含めて2つ以上のインスタンスがある場合は多重起動
        return instances.count > 1
    }
}
