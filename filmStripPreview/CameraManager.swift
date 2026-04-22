//
//  CameraManager.swift
//  filmStripPreview
//
//  Created by Michael Jelks on 4/21/26.
//

import AVFoundation
import CoreImage
import SwiftUI
import Combine

// MARK: - Color Preset Model

struct ColorPreset: Identifiable, Codable {
    let id: UUID
    var name: String
    var temperature: Double
    var tint: Double
    var maskSample: SIMD3<Float>? // Store the eyedropper sample
    
    init(id: UUID = UUID(), name: String, temperature: Double, tint: Double, maskSample: SIMD3<Float>? = nil) {
        self.id = id
        self.name = name
        self.temperature = temperature
        self.tint = tint
        self.maskSample = maskSample
    }
}

class CameraManager: NSObject, ObservableObject {
    @Published var processedImage: CGImage?
    @Published var effectEnabled = true
    @Published var temperature: Double = 0.0 // -1.0 (cool) to 1.0 (warm)
    @Published var tint: Double = 0.0 // -1.0 (green) to 1.0 (magenta)
    @Published var exposure: Double = 0.0 // -2.0 to 2.0 EV
    @Published var isMacroMode = true // Default to macro ON
    @Published var presets: [ColorPreset] = []
    @Published var selectedPresetId: UUID?
    @Published var centerCropAmount: Double = 0.0 // 0.0 (no crop) to 1.0 (heavy crop)
    @Published var isLocked = false // Lock settings to freeze conversion parameters
    
    // Eyedropper/Mask sampling
    @Published var isEyedropperActive = false
    @Published var maskSampleColor: SIMD3<Float>? = nil // RGB values of sampled mask
    
    // Locked values stored when lock is enabled
    private var lockedTemperature: Double = 0.0
    private var lockedTint: Double = 0.0
    private var lockedExposure: Double = 0.0
    private var lockedCropAmount: Double = 0.0
    private var lockedMaskSample: SIMD3<Float>? = nil
    
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.filmstrip.camera")
    private let processingQueue = DispatchQueue(label: "com.filmstrip.processing")
    
    private let context = CIContext(options: [.useSoftwareRenderer: false])
    private var currentCamera: AVCaptureDevice.Position = .back
    private var isSessionConfigured = false
    private var currentDevice: AVCaptureDevice? // Track current camera device for locking
    
    // Cache the color kernel to avoid recreating it every frame
    private lazy var c41Kernel: CIColorKernel? = {
        CIColorKernel(source: """
            kernel vec4 c41NegativeCorrection(__sample pixel, float temp, float tint, vec3 maskSample, float useSample) {
                // Step 1: Neutralize the orange mask
                // If we have a sampled mask color, calculate compensation factors dynamically
                // Otherwise use default values
                float redComp, greenComp, blueComp;
                
                // useSample is 1.0 when true, 0.0 when false
                // Check if we have valid mask sample data
                if (useSample > 0.5 && maskSample.r > 0.01 && maskSample.g > 0.01 && maskSample.b > 0.01) {
                    // Calculate compensation: Rraw / Rmask_sampled for each channel
                    // Assuming "raw" neutral should be approximately equal across channels
                    // We use the red channel as reference (it's typically least affected by orange mask)
                    redComp = 1.0;
                    greenComp = maskSample.r / maskSample.g;  // Rraw / Gmask
                    blueComp = maskSample.r / maskSample.b;   // Rraw / Bmask
                } else {
                    // Default C41 mask compensation factors with baked-in color correction
                    // Base values reduced from original (1.0, 1.5, 4.0)
                    redComp = 1.0;
                    greenComp = 1.15;  // Reduced from 1.5
                    blueComp = 2.2;    // Reduced from 4.0
                }
                
                vec3 adjusted = vec3(
                    pixel.r * redComp,
                    pixel.g * greenComp,
                    pixel.b * blueComp
                );
                
                // Step 2: Invert
                vec3 inverted = vec3(1.0) - adjusted;
                
                // Step 3: Apply base color correction (equivalent to temp=-0.80, tint=+0.80)
                // This bakes in the correction so sliders start at neutral
                float baseTemp = -0.80;
                float baseTint = 0.80;
                
                // Apply base temperature (cooler - adds blue, removes red)
                inverted.r += baseTemp * 0.15;
                inverted.b -= baseTemp * 0.15;
                
                // Apply base tint (more magenta - adds red/blue, removes green)
                inverted.r += baseTint * 0.1;
                inverted.g -= baseTint * 0.1;
                inverted.b += baseTint * 0.1;
                
                // Step 4: Apply user adjustments on top of base correction
                inverted.r += temp * 0.15;
                inverted.b -= temp * 0.15;
                
                inverted.r += tint * 0.1;
                inverted.g -= tint * 0.1;
                inverted.b += tint * 0.1;
                
                // Step 5: Clamp to valid range
                inverted = clamp(inverted, 0.0, 1.0);
                
                return vec4(inverted, pixel.a);
            }
            """
        )
    }()
    
    private let presetsKey = "colorPresets"
    
    override init() {
        super.init()
        loadPresets()
    }
    
    // MARK: - Preset Management
    
    func loadPresets() {
        if let data = UserDefaults.standard.data(forKey: presetsKey),
           let decoded = try? JSONDecoder().decode([ColorPreset].self, from: data) {
            presets = decoded
        }
    }
    
    func savePresets() {
        if let encoded = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(encoded, forKey: presetsKey)
        }
    }
    
    func addPreset(name: String) {
        let preset = ColorPreset(
            name: name, 
            temperature: temperature, 
            tint: tint,
            maskSample: maskSampleColor // Save the eyedropper sample
        )
        presets.append(preset)
        savePresets()
    }
    
    func deletePreset(id: UUID) {
        presets.removeAll { $0.id == id }
        if selectedPresetId == id {
            selectedPresetId = nil
        }
        savePresets()
    }
    
    func applyPreset(_ preset: ColorPreset) {
        temperature = preset.temperature
        tint = preset.tint
        maskSampleColor = preset.maskSample // Restore the eyedropper sample
        selectedPresetId = preset.id
    }
    
    // MARK: - Setup
    
    private func setupCamera() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
        
        // Add video input
        if let device = camera(for: currentCamera),
           let input = try? AVCaptureDeviceInput(device: device) {
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                currentDevice = device // Store device reference for locking
            }
        }
        
        // Configure video output
        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        // Set video orientation
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }
        
        captureSession.commitConfiguration()
    }
    
    private func camera(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        // If macro mode is enabled and we're on the back camera, prefer ultra-wide
        if isMacroMode && position == .back {
            let macroDevices = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInUltraWideCamera],
                mediaType: .video,
                position: position
            ).devices
            if let ultraWide = macroDevices.first {
                return ultraWide
            }
        }
        
        // Otherwise, use standard cameras
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInWideAngleCamera,
                .builtInDualCamera,
                .builtInTripleCamera,
                .builtInTelephotoCamera
            ],
            mediaType: .video,
            position: position
        ).devices
        return devices.first
    }
    
    // MARK: - Session Control
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Only setup camera once
            if !self.isSessionConfigured {
                self.setupCamera()
                self.isSessionConfigured = true
            }
            
            // Start running if not already running
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }
    
    func toggleEffect() {
        effectEnabled.toggle()
    }
    
    func toggleMacroMode() {
        isMacroMode.toggle()
        
        // Switch cameras on the back camera
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.captureSession.beginConfiguration()
            
            // Remove existing input
            if let currentInput = self.captureSession.inputs.first as? AVCaptureDeviceInput {
                self.captureSession.removeInput(currentInput)
            }
            
            // Get the appropriate camera (macro mode will select ultra-wide)
            if let device = self.camera(for: self.currentCamera),
               let input = try? AVCaptureDeviceInput(device: device) {
                if self.captureSession.canAddInput(input) {
                    self.captureSession.addInput(input)
                    self.currentDevice = device // Update device reference
                }
            }
            
            // Update orientation
            if let connection = self.videoOutput.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
            
            self.captureSession.commitConfiguration()
        }
    }
    
    func toggleLock() {
        isLocked.toggle()
        
        if isLocked {
            // Store the current parameter values when locking
            lockedTemperature = temperature
            lockedTint = tint
            lockedExposure = exposure
            lockedCropAmount = centerCropAmount
            lockedMaskSample = maskSampleColor // Lock the mask sample too
            
            // Lock camera hardware exposure and white balance on session queue
            sessionQueue.async { [weak self] in
                self?.lockCameraSettings()
            }
        } else {
            // Unlock camera hardware settings on session queue
            sessionQueue.async { [weak self] in
                self?.unlockCameraSettings()
            }
        }
    }
    
    private func lockCameraSettings() {
        guard let device = currentDevice else {
            print("⚠️ No camera device available to lock")
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            // Lock exposure at current value using custom mode for maximum control
            if device.isExposureModeSupported(.custom) {
                let currentISO = device.iso
                let currentDuration = device.exposureDuration
                device.setExposureModeCustom(duration: currentDuration, iso: currentISO) { _ in
                    print("🔒 Locked custom exposure: ISO \(currentISO), duration \(currentDuration)")
                }
            } else if device.isExposureModeSupported(.locked) {
                device.exposureMode = .locked
                print("🔒 Locked camera exposure")
            }
            
            // Lock white balance at current value
            if device.isWhiteBalanceModeSupported(.locked) {
                device.whiteBalanceMode = .locked
                print("🔒 Locked camera white balance")
            }
            
            // Lock focus
            if device.isFocusModeSupported(.locked) {
                device.focusMode = .locked
                print("🔒 Locked camera focus")
            }
            
            device.unlockForConfiguration()
            print("✅ Camera hardware locked")
        } catch {
            print("⚠️ Could not lock camera settings: \(error)")
        }
    }
    
    private func unlockCameraSettings() {
        guard let device = currentDevice else {
            print("⚠️ No camera device available to unlock")
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            // Restore continuous auto exposure
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
                print("🔓 Unlocked camera exposure")
            }
            
            // Restore continuous auto white balance
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
                print("🔓 Unlocked camera white balance")
            }
            
            // Restore continuous autofocus
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
                print("🔓 Unlocked camera focus")
            }
            
            device.unlockForConfiguration()
            print("✅ Camera hardware unlocked")
        } catch {
            print("⚠️ Could not unlock camera settings: \(error)")
        }
    }
    
    // MARK: - C41 Film Negative Processing
    
    private func applyC41CorrectionWithMaskSample(to image: CIImage, temperature: Double, tint: Double, maskSample: SIMD3<Float>?) -> CIImage? {
        guard let kernel = c41Kernel else { 
            print("⚠️ Failed to create C41 color kernel")
            return nil 
        }
        
        let maskVector = CIVector(
            x: CGFloat(maskSample?.x ?? 0.0),
            y: CGFloat(maskSample?.y ?? 0.0),
            z: CGFloat(maskSample?.z ?? 0.0)
        )
        let useSample = maskSample != nil ? 1.0 : 0.0
        
        return kernel.apply(
            extent: image.extent,
            arguments: [image, Float(temperature), Float(tint), maskVector, Float(useSample)]
        )
    }
    
    func sampleMaskColor(at point: CGPoint, from image: CGImage) {
        let ciImage = CIImage(cgImage: image)
        
        // Sample a small region around the point (3x3 pixels) to get average
        let sampleRect = CGRect(
            x: point.x - 1,
            y: point.y - 1,
            width: 3,
            height: 3
        )
        
        // Apply area average filter
        if let filter = CIFilter(name: "CIAreaAverage") {
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(CIVector(cgRect: sampleRect), forKey: kCIInputExtentKey)
            
            if let outputImage = filter.outputImage {
                var bitmap = [UInt8](repeating: 0, count: 4)
                context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
                
                // Convert to normalized float values (0.0 to 1.0)
                let r = Float(bitmap[0]) / 255.0
                let g = Float(bitmap[1]) / 255.0
                let b = Float(bitmap[2]) / 255.0
                
                maskSampleColor = SIMD3<Float>(r, g, b)
                print("🎨 Sampled mask color at \(point): R=\(r), G=\(g), B=\(b)")
            }
        }
    }
    
    private func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Use locked values if locked, otherwise use current values
        let activeTemperature = isLocked ? lockedTemperature : temperature
        let activeTint = isLocked ? lockedTint : tint
        let activeExposure = isLocked ? lockedExposure : exposure
        let activeCropAmount = isLocked ? lockedCropAmount : centerCropAmount
        let activeMaskSample = isLocked ? lockedMaskSample : maskSampleColor // Use locked mask when locked
        
        // Apply center crop if enabled (before processing to reduce edge light spill)
        if activeCropAmount > 0.0 {
            let extent = ciImage.extent
            let cropFactor = 1.0 - (activeCropAmount * 0.5) // Max 50% crop from edges
            let newWidth = extent.width * cropFactor
            let newHeight = extent.height * cropFactor
            let offsetX = (extent.width - newWidth) / 2.0
            let offsetY = (extent.height - newHeight) / 2.0
            
            let cropRect = CGRect(
                x: extent.origin.x + offsetX,
                y: extent.origin.y + offsetY,
                width: newWidth,
                height: newHeight
            )
            
            ciImage = ciImage.cropped(to: cropRect)
        }
        
        // Apply exposure compensation first
        if activeExposure != 0.0 {
            if let exposureFilter = CIFilter(name: "CIExposureAdjust") {
                exposureFilter.setValue(ciImage, forKey: kCIInputImageKey)
                exposureFilter.setValue(activeExposure, forKey: kCIInputEVKey)
                if let output = exposureFilter.outputImage {
                    ciImage = output
                }
            }
        }
        
        // Apply C41 correction if enabled (using active temp/tint and mask sample)
        if effectEnabled {
            if let corrected = applyC41CorrectionWithMaskSample(to: ciImage, temperature: activeTemperature, tint: activeTint, maskSample: activeMaskSample) {
                ciImage = corrected
            }
        }
        
        // Convert to CGImage
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        // Update UI on main thread
        DispatchQueue.main.async { [weak self] in
            self?.processedImage = cgImage
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        processFrame(sampleBuffer)
    }
}

