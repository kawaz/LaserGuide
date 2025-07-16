// AppDelegate.swift
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var screenManager = ScreenManager()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
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
        
        // メニューが開かれる前の処理
        menu.delegate = self
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func screensDidChange() {
        screenManager.setupOverlays()
    }
    
    @objc private func quitApp() {
        // アプリ終了時にマウス追跡を停止
        MouseTrackingManager.shared.stopTracking()
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - NSMenuDelegate
extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        // メニューが開かれる際も、マウス追跡は継続する
        // 特別な処理は不要だが、将来的な拡張のためにデリゲートメソッドを用意
    }
    
    func menuDidClose(_ menu: NSMenu) {
        // メニューが閉じられた後も、マウス追跡は継続する
        // 特別な処理は不要だが、将来的な拡張のためにデリゲートメソッドを用意
    }
}
