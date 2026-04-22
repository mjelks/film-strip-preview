# Eyedropper Feature Implementation Summary

## Overview
Added an eyedropper/color sampling feature that allows users to sample the orange mask color from C41 film negatives. This improves color accuracy by calculating dynamic compensation factors based on the actual film's orange mask instead of using hardcoded values.

## Changes Made

### 1. CameraManager.swift

#### New Properties
- `@Published var isEyedropperActive: Bool` - Controls eyedropper UI state
- `@Published var maskSampleColor: SIMD3<Float>?` - Stores the sampled RGB values

#### Updated C41 Kernel
The kernel now accepts mask sample data and calculates compensation factors dynamically:

```glsl
kernel vec4 c41NegativeCorrection(__sample pixel, float temp, float tint, vec3 maskSample, float useSample)
```

**Note:** CIColorKernel uses a subset of Metal Shading Language that doesn't support `bool` types, so we use `float` instead (0.0 = false, 1.0 = true).

**Key Algorithm Update:**
```glsl
if (useSample > 0.5 && maskSample.r > 0.01 && maskSample.g > 0.01 && maskSample.b > 0.01) {
    // Dynamic compensation based on sampled mask
    redComp = 1.0;
    greenComp = maskSample.r / maskSample.g;  // Rraw / Gmask
    blueComp = maskSample.r / maskSample.b;   // Rraw / Bmask
} else {
    // Default fallback values
    redComp = 1.0;
    greenComp = 1.15;
    blueComp = 2.2;
}
```

#### New Method: `sampleMaskColor(at:from:)`
Samples a 3x3 pixel area at the given point and averages the color values:
- Uses `CIAreaAverage` filter for accurate sampling
- Stores normalized RGB values (0.0 to 1.0) in `maskSampleColor`
- Prints debug info to console

### 2. ContentView.swift

#### New State Variables
- `@State private var imageViewSize: CGSize` - Tracks the displayed image size
- `@State private var imageActualSize: CGSize` - Tracks the actual image dimensions

#### Enhanced Camera Preview
- Wrapped in `GeometryReader` to track view sizes
- Added `.overlay` for eyedropper UI when active
- Added `.onTapGesture` to handle tap-to-sample interaction

#### New UI Controls

**Eyedropper Button:**
- Located above the "Lock Settings" button in the control tray
- Shows "Sample Orange Mask" or "Mask Sampled" based on state
- Displays sampled RGB values when a color is selected
- Color-coded border (orange when active, green when sampled)

**Sample Color Display:**
- Shows a color swatch of the sampled color
- Displays R, G, B values with 2 decimal precision
- Includes a clear button to reset the sample

#### New Components

**EyedropperOverlay View:**
- Semi-transparent dark overlay over the camera view
- Instructions: "Tap on orange film border"
- Close button in top-right corner
- Material design with blur effects

**Helper Function: `convertViewPointToImagePoint()`:**
- Converts tap coordinates from view space to image pixel space
- Accounts for aspect ratio and centering
- Handles both landscape and portrait orientations

## Usage Instructions

1. **Activate Eyedropper:**
   - Open the controls tray
   - Tap the "Sample Orange Mask" button
   - The screen will dim with an overlay

2. **Sample the Mask:**
   - Position the film negative so the orange border is visible
   - Tap on a clear area of the orange mask (not on image content)
   - The eyedropper will automatically close

3. **View Results:**
   - The button will change to "Mask Sampled" with a green border
   - RGB values will be displayed below the button
   - The C41 conversion will now use the sampled values

4. **Reset Sample:**
   - Tap the X button next to the RGB values
   - Or sample a new color by activating the eyedropper again

## Technical Benefits

1. **Adaptive Correction:** Handles variations in film stock and aging
2. **More Accurate Colors:** Calculates exact compensation based on actual film
3. **User Control:** Users can resample if they change film or lighting
4. **Fallback Support:** Still works with default values if no sample is taken

## Color Science

The algorithm assumes:
- The orange mask should neutralize to produce equal RGB values after compensation
- Red channel is used as the reference (least affected by orange mask)
- Compensation factors are calculated as: `referenceChannel / targetChannel`
- This maintains color balance while removing the orange cast

## Future Enhancements (Optional)

- Save mask samples with presets
- Show crosshair at tap location for precision
- Allow sampling multiple points and averaging
- Visual feedback showing the exact pixel being sampled
- Histogram display of sampled area
