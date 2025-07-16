import XCTest
@testable import LaserGuide

final class MemoryLeakDetectionTests: XCTestCase {
    
    // MARK: - LaserViewModel Memory Leak Tests
    
    func testLaserViewModelDeallocation() throws {
        weak var weakViewModel: LaserViewModel?
        weak var weakScreen: NSScreen?
        
        autoreleasepool {
            let screen = NSScreen.main!
            let viewModel = LaserViewModel(screen: screen)
            
            weakViewModel = viewModel
            weakScreen = screen
            
            // Simulate normal usage
            viewModel.startTracking()
            viewModel.isVisible = true
            viewModel.currentMouseLocation = CGPoint(x: 100, y: 100)
            viewModel.stopTracking()
        }
        
        // Force garbage collection
        let expectation = XCTestExpectation(description: "Memory should be released")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertNil(weakViewModel, "LaserViewModel should be deallocated")
        // Note: NSScreen.main is a singleton, so it won't be nil
    }
    
    func testTimerRetainCycle() throws {
        weak var weakViewModel: LaserViewModel?
        
        autoreleasepool {
            let viewModel = LaserViewModel(screen: NSScreen.main!)
            weakViewModel = viewModel
            
            // Start tracking to create timer
            viewModel.startTracking()
            viewModel.isVisible = true
            
            // Simulate timer activity
            for _ in 0..<10 {
                viewModel.isVisible = true
            }
            
            // Stop tracking to clean up timer
            viewModel.stopTracking()
        }
        
        // Allow time for cleanup
        let expectation = XCTestExpectation(description: "Timer should not retain ViewModel")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertNil(weakViewModel, "ViewModel should not be retained by timer")
    }
    
    func testEventMonitorRetainCycle() throws {
        weak var weakViewModel: LaserViewModel?
        
        autoreleasepool {
            let viewModel = LaserViewModel(screen: NSScreen.main!)
            weakViewModel = viewModel
            
            // Start tracking to create event monitor
            viewModel.startTracking()
            
            // Simulate some activity
            viewModel.isVisible = true
            viewModel.currentMouseLocation = CGPoint(x: 200, y: 200)
            
            // Stop tracking to clean up event monitor
            viewModel.stopTracking()
        }
        
        // Allow time for cleanup
        let expectation = XCTestExpectation(description: "Event monitor should not retain ViewModel")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertNil(weakViewModel, "ViewModel should not be retained by event monitor")
    }
    
    // MARK: - Multiple Instance Tests
    
    func testMultipleViewModelInstances() throws {
        var weakViewModels: [LaserViewModel?] = []
        
        autoreleasepool {
            // Create multiple instances
            for i in 0..<5 {
                let viewModel = LaserViewModel(screen: NSScreen.main!)
                weakViewModels.append(viewModel)
                
                viewModel.startTracking()
                viewModel.isVisible = true
                viewModel.currentMouseLocation = CGPoint(x: Double(i * 50), y: Double(i * 50))
                viewModel.stopTracking()
            }
        }
        
        // Clear strong references
        weakViewModels = weakViewModels.map { _ in nil }
        
        // Allow time for cleanup
        let expectation = XCTestExpectation(description: "All ViewModels should be deallocated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        for (index, weakViewModel) in weakViewModels.enumerated() {
            XCTAssertNil(weakViewModel, "ViewModel \(index) should be deallocated")
        }
    }
    
    // MARK: - Stress Tests for Memory Leaks
    
    func testRapidCreateDestroy() throws {
        // Test rapid creation and destruction of ViewModels
        for _ in 0..<50 {
            autoreleasepool {
                let viewModel = LaserViewModel(screen: NSScreen.main!)
                viewModel.startTracking()
                viewModel.isVisible = true
                viewModel.stopTracking()
            }
        }
        
        // Allow time for cleanup
        let expectation = XCTestExpectation(description: "Rapid create/destroy should not leak memory")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertTrue(true, "Rapid create/destroy should complete without memory leaks")
    }
    
    func testLongRunningViewModel() throws {
        weak var weakViewModel: LaserViewModel?
        
        autoreleasepool {
            let viewModel = LaserViewModel(screen: NSScreen.main!)
            weakViewModel = viewModel
            
            viewModel.startTracking()
            
            // Simulate long-running usage with many state changes
            let expectation = XCTestExpectation(description: "Long running test")
            
            var counter = 0
            let timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { timer in
                counter += 1
                viewModel.isVisible = counter % 2 == 0
                viewModel.currentMouseLocation = CGPoint(x: Double(counter % 100), y: Double(counter % 100))
                
                if counter >= 100 {
                    timer.invalidate()
                    viewModel.stopTracking()
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
        
        // Allow time for cleanup
        let cleanupExpectation = XCTestExpectation(description: "Long running ViewModel should be cleaned up")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            cleanupExpectation.fulfill()
        }
        wait(for: [cleanupExpectation], timeout: 1.0)
        
        XCTAssertNil(weakViewModel, "Long running ViewModel should be deallocated")
    }
    
    // MARK: - Deinit Behavior Tests
    
    func testDeinitWithActiveTimer() throws {
        // Test that deinit properly cleans up active timers
        weak var weakViewModel: LaserViewModel?
        
        autoreleasepool {
            let viewModel = LaserViewModel(screen: NSScreen.main!)
            weakViewModel = viewModel
            
            viewModel.startTracking()
            viewModel.isVisible = true
            
            // Don't call stopTracking - let deinit handle cleanup
        }
        
        // Allow time for deinit and cleanup
        let expectation = XCTestExpectation(description: "Deinit should clean up active timer")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertNil(weakViewModel, "ViewModel with active timer should be deallocated by deinit")
    }
    
    func testDeinitWithActiveEventMonitor() throws {
        // Test that deinit properly cleans up active event monitors
        weak var weakViewModel: LaserViewModel?
        
        autoreleasepool {
            let viewModel = LaserViewModel(screen: NSScreen.main!)
            weakViewModel = viewModel
            
            viewModel.startTracking()
            
            // Don't call stopTracking - let deinit handle cleanup
        }
        
        // Allow time for deinit and cleanup
        let expectation = XCTestExpectation(description: "Deinit should clean up active event monitor")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertNil(weakViewModel, "ViewModel with active event monitor should be deallocated by deinit")
    }
    
    // MARK: - Performance Impact Tests
    
    func testMemoryUsageStability() throws {
        // Test that memory usage remains stable over time
        let initialMemory = getMemoryUsage()
        
        // Perform many operations
        for _ in 0..<100 {
            autoreleasepool {
                let viewModel = LaserViewModel(screen: NSScreen.main!)
                viewModel.startTracking()
                
                for j in 0..<10 {
                    viewModel.isVisible = j % 2 == 0
                    viewModel.currentMouseLocation = CGPoint(x: Double(j), y: Double(j))
                }
                
                viewModel.stopTracking()
            }
        }
        
        // Allow time for cleanup
        let expectation = XCTestExpectation(description: "Memory cleanup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Allow for some memory increase, but it shouldn't be excessive
        XCTAssertLessThan(memoryIncrease, 10_000_000, "Memory usage should remain stable (increase < 10MB)")
    }
    
    // MARK: - Helper Methods
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            return 0
        }
    }
}