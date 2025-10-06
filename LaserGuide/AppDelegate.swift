// AppDelegate.swift
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var screenManager = ScreenManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 多重起動の防止
        if isAnotherInstanceRunning() {
            NSLog("LaserGuide: Another instance is already running. Terminating.")
            NSApp.terminate(nil)
            return
        }

        setupStatusBar()
        screenManager.setupOverlays()
        
        // グローバルマウス追跡を開始
        MouseTrackingManager.shared.startTracking()
        
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

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func toggleAutoLaunch(_ sender: NSMenuItem) {
        let newState = AutoLaunchManager.shared.toggle()
        sender.state = newState ? .on : .off
    }
    
    @objc private func screensDidChange() {
        screenManager.setupOverlays()
    }
    
    @objc private func quitApp() {
        // アプリ終了時にマウス追跡を停止
        MouseTrackingManager.shared.stopTracking()
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
