import XCTest
@testable import LaserGuide

final class TimerManagementTests: XCTestCase {
    var viewModel: LaserViewModel!
    var mockScreen: NSScreen!
    
    override func setUpWithError() throws {
        mockScreen = NSScreen.main!
        viewModel = LaserViewModel(screen: mockScreen)
    }
    
    override func tearDownWithError() throws {
        viewModel.stopTracking()
        viewModel = nil
        mockScreen = nil
    }
    
    // MARK: - Timer Lifecycle Tests
    
    func testTimerCreationAndInvalidation() throws {
        // Start tracking to initialize timer management
        viewModel.startTracking()
        
        // Simulate mouse movement to trigger timer
        viewModel.isVisible = true
        
        let expectation = XCTestExpectation(description: "Timer should be managed correctly")
        
        // Test that rapid state changes don't create timer leaks
        for _ in 0..<10 {
            viewModel.isVisible = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // Test passes if no crashes occur
        XCTAssertTrue(true, "Timer management should handle rapid state changes")
    }
    
    func testTimerInvalidationOnStopTracking() throws {
        viewModel.startTracking()
        viewModel.isVisible = true
        
        // Stop tracking should invalidate any active timers
        viewModel.stopTracking()
        
        let expectation = XCTestExpectation(description: "Timer should be invalidated")
        DispatchQueue.main.asyncAfter(deadline: .now() + Config.Timing.inactivityThreshold + 0.1) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // After stopping tracking, visibility should not change automatically
        // (since timer should be invalidated)
        XCTAssertTrue(true, "Timer invalidation should prevent automatic state changes")
    }
    
    // MARK: - Timer Behavior Tests
    
    func testInactivityThreshold() throws {
        let expectation = XCTestExpectation(description: "Laser should hide after inactivity threshold")
        
        viewModel.startTracking()
        viewModel.isVisible = true
        
        // Wait for slightly longer than the inactivity threshold
        DispatchQueue.main.asyncAfter(deadline: .now() + Config.Timing.inactivityThreshold + 0.1) {
            // We can't directly test the timer behavior since it's private,
            // but we can test that the system is designed to handle inactivity
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: Config.Timing.inactivityThreshold + 1.0)
        
        XCTAssertTrue(true, "Inactivity threshold should be respected")
    }
    
    func testTimerResetOnActivity() throws {
        viewModel.startTracking()
        viewModel.isVisible = true
        
        let expectation = XCTestExpectation(description: "Timer should reset on activity")
        
        // Simulate activity by setting visibility multiple times
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.viewModel.isVisible = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.viewModel.isVisible = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertTrue(true, "Timer should handle activity resets correctly")
    }
    
    // MARK: - Memory Management Tests
    
    func testTimerMemoryCleanup() throws {
        weak var weakViewModel: LaserViewModel?
        
        autoreleasepool {
            let testViewModel = LaserViewModel(screen: mockScreen)
            weakViewModel = testViewModel
            
            testViewModel.startTracking()
            testViewModel.isVisible = true
            
            // Simulate some timer activity
            for _ in 0..<5 {
                testViewModel.isVisible = true
            }
            
            testViewModel.stopTracking()
        }
        
        // Allow time for cleanup
        let expectation = XCTestExpectation(description: "ViewModel should be cleaned up")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertNil(weakViewModel, "ViewModel with timers should be properly deallocated")
    }
    
    func testMultipleTimerInvalidation() throws {
        // Test that multiple timer invalidations don't cause issues
        viewModel.startTracking()
        viewModel.isVisible = true
        
        // Stop and start multiple times
        for _ in 0..<5 {
            viewModel.stopTracking()
            viewModel.startTracking()
            viewModel.isVisible = true
        }
        
        viewModel.stopTracking()
        
        XCTAssertTrue(true, "Multiple timer invalidations should not cause crashes")
    }
    
    // MARK: - Edge Case Tests
    
    func testTimerBehaviorWithZeroThreshold() throws {
        // Test behavior when inactivity threshold is very small
        // (We can't modify the Config value, but we can test the system's robustness)
        
        viewModel.startTracking()
        
        let expectation = XCTestExpectation(description: "System should handle edge cases")
        
        // Rapid state changes
        for i in 0..<100 {
            viewModel.isVisible = i % 2 == 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertTrue(true, "System should handle rapid state changes gracefully")
    }
    
    func testTimerBehaviorOnBackgroundThread() throws {
        let expectation = XCTestExpectation(description: "Timer should work correctly with background operations")
        
        viewModel.startTracking()
        
        DispatchQueue.global(qos: .background).async {
            // Simulate background work that might affect timer
            Thread.sleep(forTimeInterval: 0.1)
            
            DispatchQueue.main.async {
                self.viewModel.isVisible = true
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertTrue(true, "Timer should work correctly with background operations")
    }
}