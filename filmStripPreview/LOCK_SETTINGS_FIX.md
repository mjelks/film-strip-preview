# Lock Settings Fix - Lock EVERYTHING (Including Camera Hardware)

## Problem
When "Lock Settings" was activated, the image would still change as you moved the camera because:

1. **Software parameters weren't fully locked** - The mask sample wasn't being locked
2. **Camera hardware kept auto-adjusting** - AVCaptureDevice was still doing:
   - Auto-exposure (brightness changes)
   - Auto white balance (color temperature changes)
   - Auto-focus (focus changes)

## What You Wanted
- **Lock ALL conversion parameters** (temperature, tint, exposure, crop, mask sample)
- **Lock the camera hardware** (no auto-exposure, no auto white balance)
- **Keep live preview** so you can scan through different film frames
- **Completely consistent conversion** no matter how you move the camera

## Solution
Now when you tap "Lock Settings", the app locks BOTH software and hardware:

### 1. Software Parameter Lock
```swift
private var lockedTemperature: Double = 0.0
private var lockedTint: Double = 0.0
private var lockedExposure: Double = 0.0
private var lockedCropAmount: Double = 0.0
private var lockedMaskSample: SIMD3<Float>? = nil  // Eyedropper sample
```

### 2. Camera Hardware Lock (NEW!)
```swift
private func lockCameraSettings() {
    guard let device = currentDevice else { return }
    
    try device.lockForConfiguration()
    
    // Lock exposure - freezes brightness
    device.exposureMode = .locked
    
    // Lock white balance - freezes color temperature
    device.whiteBalanceMode = .locked
    
    // Lock focus - freezes focus distance
    device.focusMode = .locked
    
    device.unlockForConfiguration()
}
```

### 3. Complete toggleLock() Behavior

**When Lock is Activated:**
```swift/Users/mjelks/Sites/projects/iOS/filmStripPreview/filmStripPreview/CameraManager.swift:304:13 Cannot find 'lockedMaskSample' in scope
func toggleLock() {
    isLocked.toggle()
    
    if isLocked {
        // Lock software parameters
        lockedTemperature = temperature
        lockedTint = tint
        lockedExposure = exposure
        lockedCropAmount = centerCropAmount
        lockedMaskSample = maskSampleColor
        
        // Lock camera hardware ⬅️ NEW!
        lockCameraSettings()
    } else {
        // Unlock camera hardware
        unlockCameraSettings()
    }
}
```

**When Lock is Deactivated:**
```swift
private func unlockCameraSettings() {
    guard let device = currentDevice else { return }
    
    try device.lockForConfiguration()
    
    // Restore continuous auto exposure
    device.exposureMode = .continuousAutoExposure
    
    // Restore continuous auto white balance
    device.whiteBalanceMode = .continuousAutoWhiteBalance
    
    // Restore continuous autofocus
    device.focusMode = .continuousAutoFocus
    
    device.unlockForConfiguration()
}
```

## Result

✅ **Everything is now truly locked:**
- ✅ Software conversion parameters (temp, tint, exposure, crop, mask sample)
- ✅ **Camera hardware exposure** (no brightness changes)
- ✅ **Camera hardware white balance** (no color shifts)
- ✅ **Camera hardware focus** (no focus changes)
- ✅ Live preview continues with locked settings

## Workflow

### Perfect Film Scanning Process:
1. **Position camera** over first frame of film strip
2. **Wait for auto-exposure** to stabilize the image
3. **Tap eyedropper** and sample the orange mask border
4. **Adjust software sliders** (temperature, tint, exposure) until perfect
5. **Tap "Lock Settings"** 🔒
   - Software parameters freeze
   - Camera hardware locks (exposure, WB, focus)
   - Console shows: `🔒 Locked camera exposure/white balance/focus`
6. **Move camera** through different frames on the film strip
7. **Every frame looks identical** - no exposure changes, no color shifts!

### Why This Matters:
- **No more brightness changes** when moving from light to dark areas
- **No more color shifts** from camera's auto white balance
- **Consistent conversion** across entire roll of film
- **Professional scanning quality** with locked exposure and color

## Technical Details

### Camera Device Tracking
```swift
private var currentDevice: AVCaptureDevice? // Track current camera
// Store device when camera is initialized
if let device = camera(for: currentCamera) {
    currentDevice = device
}
```

### Exposure Modes
- **`.continuousAutoExposure`** (default) - Camera constantly adjusts brightness
- **`.locked`** (when locked) - Camera freezes current exposure settings

### White Balance Modes
- **`.continuousAutoWhiteBalance`** (default) - Camera constantly adjusts color temperature
- **`.locked`** (when locked) - Camera freezes current white balance settings

### Focus Modes
- **`.continuousAutoFocus`** (default) - Camera constantly adjusts focus
- **`.locked`** (when locked) - Camera freezes current focus distance

### Debug Output
The console will show when settings are locked/unlocked:
```
🔒 Locked camera exposure
🔒 Locked camera white balance
🔒 Locked camera focus
```

```
🔓 Unlocked camera exposure
🔓 Unlocked camera white balance
🔓 Unlocked camera focus
```

