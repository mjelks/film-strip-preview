//
//  ContentView.swift
//  filmStripPreview
//
//  Created by Michael Jelks on 4/21/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showControls = false
    @State private var showPresetNameAlert = false
    @State private var newPresetName = ""
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var imageViewSize: CGSize = .zero
    @State private var imageActualSize: CGSize = .zero
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with exit button
                HStack {
                    Text("C41 Film Negative Preview")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Button(action: {
                        exit(0)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Camera preview with film negative effect (FULL SCREEN)
                if let image = cameraManager.processedImage {
                    GeometryReader { geometry in
                        Image(image, scale: 1.0, label: Text("Film Preview"))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.horizontal, 8)
                            .background(
                                GeometryReader { imageGeometry in
                                    Color.clear
                                        .onAppear {
                                            imageViewSize = imageGeometry.size
                                            imageActualSize = CGSize(
                                                width: CGFloat(image.width),
                                                height: CGFloat(image.height)
                                            )
                                        }
                                        .onChange(of: imageGeometry.size) { _, newSize in
                                            imageViewSize = newSize
                                        }
                                }
                            )
                            .overlay {
                                if cameraManager.isEyedropperActive {
                                    EyedropperOverlay(
                                        isActive: $cameraManager.isEyedropperActive,
                                        onSample: { location in
                                            // Convert tap location to image coordinates
                                            let imagePoint = convertViewPointToImagePoint(
                                                viewPoint: location,
                                                viewSize: imageViewSize,
                                                imageSize: imageActualSize
                                            )
                                            cameraManager.sampleMaskColor(at: imagePoint, from: image)
                                        }
                                    )
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                if cameraManager.isEyedropperActive {
                                    let imagePoint = convertViewPointToImagePoint(
                                        viewPoint: location,
                                        viewSize: imageViewSize,
                                        imageSize: imageActualSize
                                    )
                                    cameraManager.sampleMaskColor(at: imagePoint, from: image)
                                    cameraManager.isEyedropperActive = false
                                }
                            }
                    }
                } else {
                    ProgressView("Starting camera...")
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            
            // Floating button to open controls (overlaid on top)
            if !showControls {
                VStack {
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showControls = true
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 14, weight: .medium))
                            Text("Controls")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    }
                    .padding(.bottom, 40) // Above home indicator
                }
            }
            
            // Sliding control tray from bottom
            VStack {
                Spacer()
                
                VStack(spacing: 0) {
                    if showControls {
                        // Compact handle bar at top when expanded
                        VStack(spacing: 0) {
                            Capsule()
                                .fill(.white.opacity(0.3))
                                .frame(width: 36, height: 5)
                                .padding(.top, 8)
                                .padding(.bottom, 12)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDragging = true
                                    dragOffset = value.translation.height
                                }
                                .onEnded { value in
                                    isDragging = false
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        // If dragged down more than 50 points, hide controls
                                        if value.translation.height > 50 {
                                            showControls = false
                                        }
                                        dragOffset = 0
                                    }
                                }
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showControls = false
                            }
                        }
                        VStack(spacing: 16) {
                            // Preset Picker
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Presets")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.8))
                                    Spacer()
                                    Button(action: {
                                        showPresetNameAlert = true
                                    }) {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundStyle(.green)
                                    }
                                }
                                
                                if !cameraManager.presets.isEmpty {
                                    if cameraManager.presets.count > 3 {
                                        // Dropdown menu for more than 3 presets
                                        Menu {
                                            ForEach(cameraManager.presets) { preset in
                                                Button(action: {
                                                    cameraManager.applyPreset(preset)
                                                }) {
                                                    HStack {
                                                        Text(preset.name)
                                                        Spacer()
                                                        if cameraManager.selectedPresetId == preset.id {
                                                            Image(systemName: "checkmark")
                                                        }
                                                    }
                                                }
                                            }
                                            
                                            Divider()
                                            
                                            ForEach(cameraManager.presets) { preset in
                                                Button(role: .destructive, action: {
                                                    cameraManager.deletePreset(id: preset.id)
                                                }) {
                                                    Label("Delete \(preset.name)", systemImage: "trash")
                                                }
                                            }
                                        } label: {
                                            HStack {
                                                if let selectedId = cameraManager.selectedPresetId,
                                                   let selected = cameraManager.presets.first(where: { $0.id == selectedId }) {
                                                    Text(selected.name)
                                                } else {
                                                    Text("Select Preset")
                                                }
                                                Spacer()
                                                Image(systemName: "chevron.down")
                                            }
                                            .foregroundStyle(.white)
                                            .padding(8)
                                            .background(.gray.opacity(0.3))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                    } else {
                                        // Horizontal scroll for 3 or fewer presets
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 8) {
                                                ForEach(cameraManager.presets) { preset in
                                                    PresetButton(
                                                        preset: preset,
                                                        isSelected: cameraManager.selectedPresetId == preset.id,
                                                        onTap: {
                                                            cameraManager.applyPreset(preset)
                                                        },
                                                        onDelete: {
                                                            cameraManager.deletePreset(id: preset.id)
                                                        }
                                                    )
                                                }
                                            }
                                            .padding(.horizontal, 2)
                                        }
                                    }
                                } else {
                                    Text("No presets saved")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.5))
                                        .italic()
                                }
                            }
                            .padding(.horizontal)
                            
                            // Exposure Slider (like Photos app)
                            VStack(spacing: 2) {
                                HStack {
                                    Text("Exposure")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.8))
                                    Spacer()
                                    Text(String(format: "%+.1f EV", cameraManager.exposure))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                                HStack(spacing: 8) {
                                    Image(systemName: "minus")
                                        .foregroundStyle(.white.opacity(0.6))
                                        .font(.caption2)
                                    Slider(value: $cameraManager.exposure, in: -2.0...2.0)
                                        .tint(.yellow)
                                        .onTapGesture(count: 2) {
                                            withAnimation {
                                                cameraManager.exposure = 0.0
                                            }
                                        }
                                    Image(systemName: "plus")
                                        .foregroundStyle(.white.opacity(0.6))
                                        .font(.caption2)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(.horizontal)
                            
                            // Temperature Slider (Smaller)
                            VStack(spacing: 2) {
                                HStack {
                                    Text("Temperature")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.8))
                                    Spacer()
                                    Text(String(format: "%.2f", cameraManager.temperature))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                                HStack(spacing: 8) {
                                    Image(systemName: "thermometer.snowflake")
                                        .foregroundStyle(.cyan)
                                        .font(.caption2)
                                    Slider(value: $cameraManager.temperature, in: -1.0...1.0)
                                        .tint(.orange)
                                        .onTapGesture(count: 2) {
                                            withAnimation {
                                                cameraManager.temperature = 0.0
                                            }
                                        }
                                    Image(systemName: "thermometer.sun")
                                        .foregroundStyle(.orange)
                                        .font(.caption2)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(.horizontal)
                            
                            // Tint Slider (Smaller)
                            VStack(spacing: 2) {
                                HStack {
                                    Text("Tint")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.8))
                                    Spacer()
                                    Text(String(format: "%.2f", cameraManager.tint))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                                HStack(spacing: 8) {
                                    Image(systemName: "circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.caption2)
                                    Slider(value: $cameraManager.tint, in: -1.0...1.0)
                                        .tint(.pink)
                                        .onTapGesture(count: 2) {
                                            withAnimation {
                                                cameraManager.tint = 0.0
                                            }
                                        }
                                    Image(systemName: "circle.fill")
                                        .foregroundStyle(.pink)
                                        .font(.caption2)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(.horizontal)
                            
                            // Center Crop Slider to reduce edge light spill
                            VStack(spacing: 2) {
                                HStack {
                                    Text("Edge Crop")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.8))
                                    Spacer()
                                    Text(String(format: "%.0f%%", cameraManager.centerCropAmount * 100))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                                HStack(spacing: 8) {
                                    Image(systemName: "crop")
                                        .foregroundStyle(.white.opacity(0.6))
                                        .font(.caption2)
                                    Slider(value: $cameraManager.centerCropAmount, in: 0.0...1.0)
                                        .tint(.cyan)
                                        .onTapGesture(count: 2) {
                                            withAnimation {
                                                cameraManager.centerCropAmount = 0.0
                                            }
                                        }
                                    Image(systemName: "viewfinder")
                                        .foregroundStyle(.cyan)
                                        .font(.caption2)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(.horizontal)
                            
                            // Eyedropper button to sample mask color
                            VStack(spacing: 4) {
                                Button(action: {
                                    cameraManager.isEyedropperActive.toggle()
                                }) {
                                    HStack {
                                        Image(systemName: "eyedropper")
                                        Text(cameraManager.maskSampleColor == nil ? "Sample Orange Mask" : "Mask Sampled")
                                            .font(.caption)
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(cameraManager.isEyedropperActive ? Color.orange.opacity(0.3) : (cameraManager.maskSampleColor != nil ? Color.green.opacity(0.3) : Color.clear))
                                    )
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(cameraManager.isEyedropperActive ? Color.orange : (cameraManager.maskSampleColor != nil ? Color.green : Color.clear), lineWidth: 2)
                                    )
                                }
                                
                                if let sample = cameraManager.maskSampleColor {
                                    HStack {
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(Color(red: Double(sample.x), green: Double(sample.y), blue: Double(sample.z)))
                                                .frame(width: 16, height: 16)
                                                .overlay(Circle().stroke(.white, lineWidth: 1))
                                            Text("R: \(String(format: "%.2f", sample.x))")
                                                .font(.caption2.monospacedDigit())
                                            Text("G: \(String(format: "%.2f", sample.y))")
                                                .font(.caption2.monospacedDigit())
                                            Text("B: \(String(format: "%.2f", sample.z))")
                                                .font(.caption2.monospacedDigit())
                                        }
                                        Spacer()
                                        Button(action: {
                                            cameraManager.maskSampleColor = nil
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.red.opacity(0.8))
                                                .font(.caption)
                                        }
                                    }
                                    .foregroundStyle(.white.opacity(0.7))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.black.opacity(0.3))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                            .padding(.horizontal)
                            
                            // Lock Settings Button
                            Button(action: {
                                cameraManager.toggleLock()
                            }) {
                                HStack {
                                    Image(systemName: cameraManager.isLocked ? "lock.fill" : "lock.open.fill")
                                    Text(cameraManager.isLocked ? "Settings Locked" : "Lock Settings")
                                        .font(.caption)
                                }
                                .foregroundStyle(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(cameraManager.isLocked ? Color.blue.opacity(0.3) : Color.clear)
                                )
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(cameraManager.isLocked ? Color.blue : Color.clear, lineWidth: 2)
                                )
                            }
                            .padding(.horizontal)
                            
                            // Macro toggle button
                            Button(action: {
                                cameraManager.toggleMacroMode()
                            }) {
                                HStack {
                                    Image(systemName: "camera.macro")
                                    Text(cameraManager.isMacroMode ? "Macro Mode: ON" : "Macro Mode: OFF")
                                        .font(.caption)
                                }
                                .foregroundStyle(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(cameraManager.isMacroMode ? Color.orange.opacity(0.3) : Color.clear)
                                )
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(cameraManager.isMacroMode ? Color.orange : Color.clear, lineWidth: 2)
                                )
                            }
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 24) // Extra padding for home indicator area
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.3), radius: 10, y: -5)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .onAppear {
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .alert("Save Preset", isPresented: $showPresetNameAlert) {
            TextField("Preset Name", text: $newPresetName)
            Button("Cancel", role: .cancel) {
                newPresetName = ""
            }
            Button("Save") {
                if !newPresetName.isEmpty {
                    cameraManager.addPreset(name: newPresetName)
                    newPresetName = ""
                }
            }
        } message: {
            Text("Enter a name for this color preset (Temp: \(String(format: "%.2f", cameraManager.temperature)), Tint: \(String(format: "%.2f", cameraManager.tint)))")
        }
    }
    
    // Helper function to convert view coordinates to image coordinates
    private func convertViewPointToImagePoint(viewPoint: CGPoint, viewSize: CGSize, imageSize: CGSize) -> CGPoint {
        // Calculate the displayed image size (accounting for aspect fit)
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height
        
        var displayedSize: CGSize
        if imageAspect > viewAspect {
            // Image is wider - constrained by width
            displayedSize = CGSize(width: viewSize.width, height: viewSize.width / imageAspect)
        } else {
            // Image is taller - constrained by height
            displayedSize = CGSize(width: viewSize.height * imageAspect, height: viewSize.height)
        }
        
        // Calculate offset (image is centered in view)
        let offsetX = (viewSize.width - displayedSize.width) / 2
        let offsetY = (viewSize.height - displayedSize.height) / 2
        
        // Convert to image coordinates
        let relativeX = (viewPoint.x - offsetX) / displayedSize.width
        let relativeY = (viewPoint.y - offsetY) / displayedSize.height
        
        return CGPoint(
            x: relativeX * imageSize.width,
            y: relativeY * imageSize.height
        )
    }
}

// MARK: - Eyedropper Overlay

struct EyedropperOverlay: View {
    @Binding var isActive: Bool
    let onSample: (CGPoint) -> Void
    @State private var tapLocation: CGPoint?
    
    var body: some View {
        ZStack {
            // Semi-transparent overlay
            Color.black.opacity(0.3)
            
            // Instructions
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        isActive = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding()
                    }
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Image(systemName: "eyedropper.halffull")
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                    
                    Text("Tap on orange film border")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text("Sample the orange mask color\nfor accurate color conversion")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 10)
                
                Spacer()
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Preset Button Component

struct PresetButton: View {
    let preset: ColorPreset
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(preset.name)
                        .font(.caption.bold())
                        .lineLimit(1)
                    Spacer()
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Image(systemName: "thermometer")
                            .font(.caption2)
                        Text(String(format: "%.1f", preset.temperature))
                            .font(.caption2.monospacedDigit())
                    }
                    HStack(spacing: 2) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                        Text(String(format: "%.1f", preset.tint))
                            .font(.caption2.monospacedDigit())
                    }
                }
                .foregroundStyle(.white.opacity(0.7))
            }
            .foregroundStyle(.white)
            .padding(8)
            .frame(minWidth: 120)
            .background(isSelected ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}

#Preview {
    ContentView()
}
