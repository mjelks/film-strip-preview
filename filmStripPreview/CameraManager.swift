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
    
    init(id: UUID = UUID(), name: String, temperature: Double, tint: Double) {
        self.id = id
        self.name = name
        self.temperature = temperature
        self.tint = tint
    }
}

class CameraManager: NSObject, ObservableObject {
    @Published var processedImage: CGImage?
    @Published var effectEnabled = true
    @Published var temperature: Double = 0.0 // -1.0 (cool) to 1.0 (warm)
    @Published var tint: Double = 0.0 // -1.0 (green) to 1.0 (magenta)
    @Published var isMacroMode = true // Default to macro ON
    @Published var presets: [ColorPreset] = []
    @Published var selectedPresetId: UUID?
    
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.filmstrip.camera")
    private let processingQueue = DispatchQueue(label: "com.filmstrip.processing")
    
    private let context = CIContext(options: [.useSoftwareRenderer: false])
    private var currentCamera: AVCaptureDevice.Position = .back
    private var isSessionConfigured = false
    
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
        let preset = ColorPreset(name: name, temperature: temperature, tint: tint)
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
    
    // MARK: - C41 Film Negative Processing
    
    private func applyC41Correction(to image: CIImage) -> CIImage? {
        // Step 1: Create a custom kernel for the C41 correction
        // This applies the mask neutralization, inversion, and clamping in one pass
        
        let kernel = CIColorKernel(source: """
            kernel vec4 c41NegativeCorrection(__sample pixel, float temp, float tint) {
                // Step 1: Neutralize the orange mask
                // Updated C41 mask compensation factors with baked-in color correction
                // Base values reduced from original (1.0, 1.5, 4.0)
                float redComp = 1.0;
                float greenComp = 1.15;  // Reduced from 1.5
                float blueComp = 2.2;    // Reduced from 4.0
                
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
        
        guard let kernel = kernel else { return nil }
        
        return kernel.apply(
            extent: image.extent,
            arguments: [image, Float(temperature), Float(tint)]
        )
    }
    
    private func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Apply C41 correction if enabled
        if effectEnabled {
            if let corrected = applyC41Correction(to: ciImage) {
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

