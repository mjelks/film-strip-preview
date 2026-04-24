# Test Fix: Parallel Execution Issue

## Problem

Tests were failing with race conditions:
```
error: presetManagement(): Expectation failed: (manager.presets → [filmStripPreview.ColorPreset(id: 7A8E4BDA-76EB-465C-94B9-41C1B95C1D35, name: "Persistent Preset", temperature: 0.5, tint: -0.3, maskSample: nil)]).isEmpty → false: // Verify starting clean

error: presetPersistence(): Expectation failed: (manager2.presets.count → 0) == 1
```

## Root Cause

**Swift Testing runs tests in parallel by default**. Multiple test methods in `CameraManagerTests` were:
1. Running simultaneously 
2. Accessing the same `UserDefaults` storage
3. Creating race conditions where:
   - Test A clears UserDefaults
   - Test B writes a preset
   - Test A reads UserDefaults (sees Test B's data)
   - Test A fails because it expected empty data

## Solution

Added `.serialized` trait to the `CameraManagerTests` suite:

```swift
@Suite("Camera Manager Tests", .serialized)
struct CameraManagerTests {
    // ...
}
```

## What `.serialized` Does

- **Forces sequential execution** of all tests within the suite
- Tests run one at a time, preventing concurrent access to shared resources
- UserDefaults is now accessed by only one test at a time
- Each test completes its cleanup before the next test starts

## Why This Works

1. **Test Order Guarantee**: Tests execute in a predictable sequence
2. **No Race Conditions**: No overlapping reads/writes to UserDefaults
3. **Proper Cleanup**: `clearPresets()` fully completes before next test starts
4. **State Isolation**: Each test gets a clean slate

## Trade-offs

- **Slower execution**: Tests run sequentially instead of in parallel
- **Acceptable**: These tests access a shared resource (UserDefaults) that cannot be parallelized safely
- **Alternative avoided**: Could have used a mock UserDefaults, but that adds complexity and doesn't test the real persistence behavior

## Other Suites

Other test suites (`ColorPresetTests`, `CoordinateConversionTests`, etc.) remain parallelized because they:
- Don't access shared resources
- Test pure functions or isolated objects
- Benefit from parallel execution speed

## Verification

All tests should now pass consistently:
- ✅ `initialState()` - Clean start every time
- ✅ `presetManagement()` - No contamination from other tests
- ✅ `presetPersistence()` - Sequential execution ensures proper save/load cycle
- ✅ All other CameraManager tests - Isolated execution

## Best Practices Learned

1. **Identify shared resources**: UserDefaults, file system, databases
2. **Use `.serialized` for suites** that access shared resources
3. **Keep other suites parallel** for performance
4. **Clean up at start AND end** of tests for robustness
5. **Force synchronization** with `UserDefaults.standard.synchronize()` when needed
