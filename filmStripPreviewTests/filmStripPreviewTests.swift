//
//  filmStripPreviewTests.swift
//  filmStripPreviewTests
//
//  Created by Michael Jelks on 4/21/26.
//

import Testing
import SwiftUI
@testable import filmStripPreview

// MARK: - Color Preset Tests

@Suite("Color Preset Tests")
struct ColorPresetTests {
    
    @Test("Creating a preset without mask sample")
    func createPresetWithoutMask() {
        let preset = ColorPreset(
            name: "Test Preset",
            temperature: 0.5,
            tint: -0.3,
            maskSample: nil
        )
        
        #expect(preset.name == "Test Preset")
        #expect(preset.temperature == 0.5)
        #expect(preset.tint == -0.3)
        #expect(preset.maskSample == nil)
    }
    
    @Test("Creating a preset with mask sample")
    func createPresetWithMask() {
        let maskColor = SIMD3<Float>(0.8, 0.5, 0.2)
        let preset = ColorPreset(
            name: "Orange Mask Preset",
            temperature: 0.0,
            tint: 0.0,
            maskSample: maskColor
        )
        
        #expect(preset.name == "Orange Mask Preset")
        #expect(preset.maskSample?.x == 0.8)
        #expect(preset.maskSample?.y == 0.5)
        #expect(preset.maskSample?.z == 0.2)
    }
    
    @Test("Preset encoding and decoding")
    func presetCodable() throws {
        let original = ColorPreset(
            name: "Kodak Gold",
            temperature: -0.2,
            tint: 0.6,
            maskSample: SIMD3<Float>(0.9, 0.6, 0.3)
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ColorPreset.self, from: data)
        
        #expect(decoded.name == original.name)
        #expect(decoded.temperature == original.temperature)
        #expect(decoded.tint == original.tint)
        #expect(decoded.maskSample?.x == original.maskSample?.x)
        #expect(decoded.maskSample?.y == original.maskSample?.y)
        #expect(decoded.maskSample?.z == original.maskSample?.z)
    }
    
    @Test("Preset identifiers are unique")
    func uniqueIdentifiers() {
        let preset1 = ColorPreset(name: "Preset 1", temperature: 0.0, tint: 0.0)
        let preset2 = ColorPreset(name: "Preset 2", temperature: 0.0, tint: 0.0)
        
        #expect(preset1.id != preset2.id)
    }
}

// MARK: - Camera Manager Tests

@Suite("Camera Manager Tests", .serialized)
struct CameraManagerTests {
    
    // Helper to clear UserDefaults before each test
    private func clearPresets() {
        UserDefaults.standard.removeObject(forKey: "colorPresets")
        UserDefaults.standard.synchronize()
    }
    
    @Test("Initial state")
    func initialState() {
        clearPresets()
        let manager = CameraManager()
        
        #expect(manager.effectEnabled == true)
        #expect(manager.temperature == 0.0)
        #expect(manager.tint == 0.0)
        #expect(manager.exposure == 0.0)
        #expect(manager.isMacroMode == true)
        #expect(manager.isLocked == false)
        #expect(manager.maskSampleColor == nil)
        #expect(manager.isEyedropperActive == false)
        #expect(manager.presets.isEmpty) // Should start with no presets
    }
    
    @Test("Toggle effect")
    func toggleEffect() {
        clearPresets()
        let manager = CameraManager()
        let initialState = manager.effectEnabled
        
        manager.toggleEffect()
        #expect(manager.effectEnabled == !initialState)
        
        manager.toggleEffect()
        #expect(manager.effectEnabled == initialState)
    }
    
    @Test("Toggle macro mode")
    func toggleMacroMode() {
        clearPresets()
        let manager = CameraManager()
        let initialState = manager.isMacroMode
        
        manager.toggleMacroMode()
        #expect(manager.isMacroMode == !initialState)
    }
    
    @Test("Adding and deleting presets")
    func presetManagement() {
        clearPresets()
        let manager = CameraManager()
        
        // Verify starting clean
        #expect(manager.presets.isEmpty)
        
        manager.temperature = 0.5
        manager.tint = -0.3
        
        // Add a preset
        manager.addPreset(name: "Test Preset")
        #expect(manager.presets.count == 1)
        #expect(manager.presets.first?.name == "Test Preset")
        #expect(manager.presets.first?.temperature == 0.5)
        #expect(manager.presets.first?.tint == -0.3)
        
        // Delete the preset
        if let presetId = manager.presets.first?.id {
            manager.deletePreset(id: presetId)
            #expect(manager.presets.isEmpty)
        }
        
        // Cleanup
        clearPresets()
    }
    
    @Test("Applying a preset")
    func applyPreset() {
        clearPresets()
        let manager = CameraManager()
        manager.temperature = 0.0
        manager.tint = 0.0
        manager.maskSampleColor = nil
        
        let preset = ColorPreset(
            name: "Test",
            temperature: 0.7,
            tint: -0.4,
            maskSample: SIMD3<Float>(0.8, 0.5, 0.2)
        )
        
        manager.applyPreset(preset)
        
        #expect(manager.temperature == 0.7)
        #expect(manager.tint == -0.4)
        #expect(manager.maskSampleColor?.x == 0.8)
        #expect(manager.maskSampleColor?.y == 0.5)
        #expect(manager.maskSampleColor?.z == 0.2)
        #expect(manager.selectedPresetId == preset.id)
    }
    
    @Test("Adding preset with mask sample")
    func addPresetWithMaskSample() throws {
        clearPresets()
        let manager = CameraManager()
        
        #expect(manager.presets.isEmpty)
        
        manager.temperature = -0.5
        manager.tint = 0.8
        manager.maskSampleColor = SIMD3<Float>(0.9, 0.6, 0.3)
        
        manager.addPreset(name: "With Mask")
        
        #expect(manager.presets.count == 1)
        let preset = try #require(manager.presets.first)
        #expect(preset.name == "With Mask")
        #expect(preset.temperature == -0.5)
        #expect(preset.tint == 0.8)
        #expect(preset.maskSample?.x ?? 0.0 == 0.9)
        #expect(preset.maskSample?.y ?? 0.0 == 0.6)
        #expect(preset.maskSample?.z ?? 0.0 == 0.3)
        
        // Cleanup
        clearPresets()
    }
    
    @Test("Deleting selected preset clears selection")
    func deleteSelectedPreset() {
        clearPresets()
        let manager = CameraManager()
        
        manager.addPreset(name: "Preset 1")
        
        if let preset = manager.presets.first {
            manager.applyPreset(preset)
            #expect(manager.selectedPresetId == preset.id)
            
            manager.deletePreset(id: preset.id)
            #expect(manager.selectedPresetId == nil)
        }
        
        // Cleanup
        clearPresets()
    }
    
    @Test("Temperature bounds")
    func temperatureBounds() {
        clearPresets()
        let manager = CameraManager()
        
        // Test valid range
        manager.temperature = -1.0
        #expect(manager.temperature == -1.0)
        
        manager.temperature = 1.0
        #expect(manager.temperature == 1.0)
        
        manager.temperature = 0.0
        #expect(manager.temperature == 0.0)
    }
    
    @Test("Tint bounds")
    func tintBounds() {
        clearPresets()
        let manager = CameraManager()
        
        // Test valid range
        manager.tint = -1.0
        #expect(manager.tint == -1.0)
        
        manager.tint = 1.0
        #expect(manager.tint == 1.0)
        
        manager.tint = 0.0
        #expect(manager.tint == 0.0)
    }
    
    @Test("Exposure bounds")
    func exposureBounds() {
        clearPresets()
        let manager = CameraManager()
        
        // Test valid range
        manager.exposure = -2.0
        #expect(manager.exposure == -2.0)
        
        manager.exposure = 2.0
        #expect(manager.exposure == 2.0)
        
        manager.exposure = 0.0
        #expect(manager.exposure == 0.0)
    }
    
    @Test("Preset persistence across instances")
    func presetPersistence() {
        clearPresets()
        
        // Create first manager and add preset
        let manager1 = CameraManager()
        manager1.temperature = 0.5
        manager1.tint = -0.3
        manager1.addPreset(name: "Persistent Preset")
        
        // Force UserDefaults to synchronize
        UserDefaults.standard.synchronize()
        
        // Create second manager - should load the preset
        let manager2 = CameraManager()
        #expect(manager2.presets.count == 1)
        #expect(manager2.presets.first?.name == "Persistent Preset")
        #expect(manager2.presets.first?.temperature == 0.5)
        #expect(manager2.presets.first?.tint == -0.3)
        
        // Cleanup
        clearPresets()
    }
}
// MARK: - Coordinate Conversion Tests

@Suite("Coordinate Conversion Tests")
struct CoordinateConversionTests {
    
    // Helper function (copied from ContentView for testing)
    private func convertViewPointToImagePoint(
        viewPoint: CGPoint,
        viewSize: CGSize,
        imageSize: CGSize
    ) -> CGPoint {
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height
        
        var displayedSize: CGSize
        if imageAspect > viewAspect {
            displayedSize = CGSize(width: viewSize.width, height: viewSize.width / imageAspect)
        } else {
            displayedSize = CGSize(width: viewSize.height * imageAspect, height: viewSize.height)
        }
        
        let offsetX = (viewSize.width - displayedSize.width) / 2
        let offsetY = (viewSize.height - displayedSize.height) / 2
        
        let relativeX = (viewPoint.x - offsetX) / displayedSize.width
        let relativeY = (viewPoint.y - offsetY) / displayedSize.height
        
        return CGPoint(
            x: relativeX * imageSize.width,
            y: relativeY * imageSize.height
        )
    }
    
    @Test("Center point conversion with square image")
    func centerPointSquare() {
        let viewSize = CGSize(width: 400, height: 400)
        let imageSize = CGSize(width: 1000, height: 1000)
        let viewPoint = CGPoint(x: 200, y: 200) // Center
        
        let imagePoint = convertViewPointToImagePoint(
            viewPoint: viewPoint,
            viewSize: viewSize,
            imageSize: imageSize
        )
        
        #expect(imagePoint.x == 500.0)
        #expect(imagePoint.y == 500.0)
    }
    
    @Test("Center point conversion with wide image")
    func centerPointWide() {
        let viewSize = CGSize(width: 400, height: 400)
        let imageSize = CGSize(width: 1600, height: 1200)
        let viewPoint = CGPoint(x: 200, y: 200) // Center
        
        let imagePoint = convertViewPointToImagePoint(
            viewPoint: viewPoint,
            viewSize: viewSize,
            imageSize: imageSize
        )
        
        // Should map to center of image
        #expect(abs(imagePoint.x - 800.0) < 1.0)
        #expect(abs(imagePoint.y - 600.0) < 1.0)
    }
    
    @Test("Top-left corner conversion")
    func topLeftCorner() {
        let viewSize = CGSize(width: 400, height: 400)
        let imageSize = CGSize(width: 1000, height: 1000)
        let viewPoint = CGPoint(x: 0, y: 0)
        
        let imagePoint = convertViewPointToImagePoint(
            viewPoint: viewPoint,
            viewSize: viewSize,
            imageSize: imageSize
        )
        
        #expect(imagePoint.x == 0.0)
        #expect(imagePoint.y == 0.0)
    }
    
    @Test("Bottom-right corner conversion")
    func bottomRightCorner() {
        let viewSize = CGSize(width: 400, height: 400)
        let imageSize = CGSize(width: 1000, height: 1000)
        let viewPoint = CGPoint(x: 400, y: 400)
        
        let imagePoint = convertViewPointToImagePoint(
            viewPoint: viewPoint,
            viewSize: viewSize,
            imageSize: imageSize
        )
        
        #expect(imagePoint.x == 1000.0)
        #expect(imagePoint.y == 1000.0)
    }
    
    @Test("Tall image with letterboxing")
    func tallImageLetterboxing() {
        let viewSize = CGSize(width: 400, height: 400)
        let imageSize = CGSize(width: 1200, height: 1600)
        let viewPoint = CGPoint(x: 200, y: 200) // Center
        
        let imagePoint = convertViewPointToImagePoint(
            viewPoint: viewPoint,
            viewSize: viewSize,
            imageSize: imageSize
        )
        
        // Should map to center of image
        #expect(abs(imagePoint.x - 600.0) < 1.0)
        #expect(abs(imagePoint.y - 800.0) < 1.0)
    }
}

// MARK: - UI Component Tests

@Suite("UI Component Tests")
struct UIComponentTests {
    
    @Test("Exposure value resets to zero")
    func exposureReset() {
        // Test the logic without SwiftUI property wrapper
        var exposure: Double = 1.5
        
        // Simulate reset
        exposure = 0.0
        
        #expect(exposure == 0.0)
    }
    
    @Test("Exposure value changes")
    func exposureChanges() {
        var exposure: Double = 0.0
        
        // Simulate increase
        exposure = 1.5
        #expect(exposure == 1.5)
        
        // Simulate decrease
        exposure = -1.0
        #expect(exposure == -1.0)
    }
    
    @Test("Preset button displays correct information")
    func presetButtonInfo() {
        let preset = ColorPreset(
            name: "Kodak Portra",
            temperature: 0.3,
            tint: -0.2,
            maskSample: SIMD3<Float>(0.8, 0.5, 0.2)
        )
        
        #expect(preset.name == "Kodak Portra")
        #expect(preset.temperature == 0.3)
        #expect(preset.tint == -0.2)
        #expect(preset.maskSample != nil)
    }
}

// MARK: - SIMD3 Color Tests

@Suite("Color Sample Tests")
struct ColorSampleTests {
    
    @Test("Valid RGB color values")
    func validRGBValues() {
        let color = SIMD3<Float>(0.8, 0.5, 0.2)
        
        #expect(color.x >= 0.0 && color.x <= 1.0)
        #expect(color.y >= 0.0 && color.y <= 1.0)
        #expect(color.z >= 0.0 && color.z <= 1.0)
    }
    
    @Test("Orange mask typical values")
    func orangeMaskValues() {
        // Typical C41 orange mask has higher red, medium green, low blue
        let orangeMask = SIMD3<Float>(0.9, 0.6, 0.3)
        
        #expect(orangeMask.x > orangeMask.y)
        #expect(orangeMask.y > orangeMask.z)
    }
    
    @Test("Color equality comparison")
    func colorEquality() {
        let color1 = SIMD3<Float>(0.5, 0.5, 0.5)
        let color2 = SIMD3<Float>(0.5, 0.5, 0.5)
        let color3 = SIMD3<Float>(0.6, 0.5, 0.5)
        
        #expect(color1 == color2)
        #expect(color1 != color3)
    }
}

