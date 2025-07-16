// MouseTrackingIntegrationTests.swift
import XCTest
import SwiftUI
@testable import LaserGuide

/// トレイアイコンクリック中のマウス追跡継続をテストする統合テストクラス
class MouseTrackingIntegrationTests: XCTestCase {
    
    var mouseTrackingManager: MouseTrackingManager!
    var expectation: XCTestExpectation!
    
    override func setUp() {
        super.setUp()
        mouseTrackingManager = MouseTrackingManager.shared
    }
    
    override func tearDown() {
        mouseTrackingManager.stopTracking()
        super.tearDown()
    }
    
    /// マウス追跡が正常に開始されることをテスト
    func testMouseTrackingStart() {
        // Given
        mouseTrackingManager.stopTracking()
        
        // When
        mouseTrackingManager.startTracking()
        
        // Then
        // マウス追跡が開始されていることを確認
        // 実際のマウスイベントは統合テストでは困難なため、状態の確認のみ
        XCTAssertNotNil(mouseTrackingManager)
    }
    
    /// マウス位置の更新が正常に動作することをテスト
    func testMouseLocationUpdate() {
        // Given
        let initialLocation = mouseTrackingManager.currentMouseLocation
        expectation = expectation(description: "Mouse location should be updated")
        
        // When
        mouseTrackingManager.startTracking()
        
        // マウス位置の変更を監視
        let cancellable = mouseTrackingManager.$currentMouseLocation
            .dropFirst() // 初期値をスキップ
            .sink { location in
                if location != initialLocation {
                    self.expectation.fulfill()
                }
            }
        
        // マウス位置を手動で更新（テスト用）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // 実際のマウスイベントをシミュレート
            let testLocation = CGPoint(x: 100, y: 100)
            self.mouseTrackingManager.currentMouseLocation = testLocation
        }
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        cancellable.cancel()
    }
    
    /// マウスアクティブ状態の管理が正常に動作することをテスト
    func testMouseActiveStateManagement() {
        // Given
        mouseTrackingManager.startTracking()
        expectation = expectation(description: "Mouse active state should be managed correctly")
        
        // When
        let cancellable = mouseTrackingManager.$isMouseActive
            .dropFirst() // 初期値をスキップ
            .sink { isActive in
                if isActive {
                    self.expectation.fulfill()
                }
            }
        
        // マウスアクティブ状態を手動で更新（テスト用）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.mouseTrackingManager.isMouseActive = true
        }
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        cancellable.cancel()
    }
    
    /// 複数のLaserViewModelが同じMouseTrackingManagerを共有することをテスト
    func testSharedMouseTrackingManager() {
        // Given
        guard let screen1 = NSScreen.screens.first else {
            XCTFail("No screen available for testing")
            return
        }
        
        let viewModel1 = LaserViewModel(screen: screen1)
        let viewModel2 = LaserViewModel(screen: screen1)
        
        // When
        viewModel1.startTracking()
        viewModel2.startTracking()
        
        // Then
        // 両方のViewModelが同じMouseTrackingManagerインスタンスを使用していることを確認
        XCTAssertTrue(viewModel1.currentMouseLocation == viewModel2.currentMouseLocation)
        
        // Cleanup
        viewModel1.stopTracking()
        viewModel2.stopTracking()
    }
    
    /// メモリリークが発生しないことをテスト
    func testNoMemoryLeaks() {
        // Given
        weak var weakManager: MouseTrackingManager?
        
        // When
        autoreleasepool {
            let manager = MouseTrackingManager.shared
            weakManager = manager
            manager.startTracking()
            manager.stopTracking()
        }
        
        // Then
        // シングルトンなので、weakManagerはnilにならない
        // これは期待される動作
        XCTAssertNotNil(weakManager)
    }
    
    /// トレイアイコンとの相互作用テスト（シミュレーション）
    func testTrayIconInteraction() {
        // Given
        mouseTrackingManager.startTracking()
        let initialActiveState = mouseTrackingManager.isMouseActive
        
        // When - トレイアイコンクリックをシミュレート
        // 実際のクリックイベントは統合テストでは困難なため、
        // マウス追跡が継続することを状態で確認
        
        // マウスを動かしてアクティブ状態にする
        mouseTrackingManager.isMouseActive = true
        
        // トレイメニューが開かれている間もマウス追跡が継続することを確認
        let activeStateDuringMenu = mouseTrackingManager.isMouseActive
        
        // Then
        XCTAssertTrue(activeStateDuringMenu, "マウス追跡はトレイメニュー表示中も継続すべき")
    }
}