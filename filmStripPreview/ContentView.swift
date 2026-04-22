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
    @State private var presetToDelete: ColorPreset? = nil
    @State private var showDeleteConfirmation = false
    
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
            
            // Floating icons overlay (lower left: Macro, Lock, Exposure, Eyedropper; lower right: Hamburger menu)
            VStack {
                Spacer()
                
                HStack(alignment: .bottom) {
                    // Left side: Macro, Lock, Exposure, Eyedropper icons
                    HStack(spacing: 12) {
                        // Macro Mode Toggle
                        Button(action: {
                            cameraManager.toggleMacroMode()
                        }) {
                            Image(systemName: "camera.macro")
                                .font(.system(size: 24))
                                .foregroundStyle(cameraManager.isMacroMode ? .orange : .white)
                                .frame(width: 50, height: 50)
                                .background(cameraManager.isMacroMode ? Color.orange.opacity(0.2) : Color.black.opacity(0.5))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(cameraManager.isMacroMode ? Color.orange : Color.white.opacity(0.3), lineWidth: 2)
                                )
                        }
                        
                        // Lock Settings Toggle
                        Button(action: {
                            cameraManager.toggleLock()
                        }) {
                            Image(systemName: cameraManager.isLocked ? "lock.fill" : "lock.open.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(cameraManager.isLocked ? .blue : .white)
                                .frame(width: 50, height: 50)
                                .background(cameraManager.isLocked ? Color.blue.opacity(0.2) : Color.black.opacity(0.5))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(cameraManager.isLocked ? Color.blue : Color.white.opacity(0.3), lineWidth: 2)
                                )
                        }
                        
                        // Exposure Control (Long Press)
                        ExposureButton(exposure: $cameraManager.exposure)
                        
                        // Eyedropper Toggle
                        Button(action: {
                            cameraManager.isEyedropperActive.toggle()
                        }) {
                            Image(systemName: cameraManager.maskSampleColor != nil ? "eyedropper.halffull" : "eyedropper")
                                .font(.system(size: 24))
                                .foregroundStyle(cameraManager.isEyedropperActive ? .orange : (cameraManager.maskSampleColor != nil ? .green : .white))
                                .frame(width: 50, height: 50)
                                .background(
                                    cameraManager.isEyedropperActive ? Color.orange.opacity(0.2) : 
                                    (cameraManager.maskSampleColor != nil ? Color.green.opacity(0.2) : Color.black.opacity(0.5))
                                )
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(
                                            cameraManager.isEyedropperActive ? Color.orange : 
                                            (cameraManager.maskSampleColor != nil ? Color.green : Color.white.opacity(0.3)), 
                                            lineWidth: 2
                                        )
                                )
                        }
                    }
                    .padding(.leading, 20)
                    
                    Spacer()
                    
                    // Right side: Hamburger menu
                    if !showControls {
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showControls = true
                            }
                        }) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 24))
                                .foregroundStyle(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                )
                        }
                        .padding(.trailing, 20)
                    }
                }
                .padding(.bottom, 40)
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
                                                    presetToDelete = preset
                                                    showDeleteConfirmation = true
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
                                                            presetToDelete = preset
                                                            showDeleteConfirmation = true
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
            if cameraManager.maskSampleColor != nil {
                Text("Saving: Temp: \(String(format: "%.2f", cameraManager.temperature)), Tint: \(String(format: "%.2f", cameraManager.tint)), and eyedropper mask sample")
            } else {
                Text("Saving: Temp: \(String(format: "%.2f", cameraManager.temperature)), Tint: \(String(format: "%.2f", cameraManager.tint)) (no mask sample)")
            }
        }
        .confirmationDialog(
            "Delete Preset",
            isPresented: $showDeleteConfirmation,
            presenting: presetToDelete
        ) { preset in
            Button("Delete \"\(preset.name)\"", role: .destructive) {
                cameraManager.deletePreset(id: preset.id)
                presetToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                presetToDelete = nil
            }
        } message: { preset in
            Text("Are you sure you want to delete the preset \"\(preset.name)\"? This action cannot be undone.")
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

// MARK: - Exposure Button Component

struct ExposureButton: View {
    @Binding var exposure: Double
    @State private var showSlider = false
    
    var body: some View {
        ZStack {
            // Main exposure button
            Button(action: {
                // Tap resets to 0
                withAnimation {
                    exposure = 0.0
                }
            }) {
                ZStack {
                    Image(systemName: "plus.slash.minus")
                        .font(.system(size: 24))
                        .foregroundStyle(exposure != 0 ? .yellow : .white)
                        .frame(width: 50, height: 50)
                        .background(exposure != 0 ? Color.yellow.opacity(0.2) : Color.black.opacity(0.5))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(exposure != 0 ? Color.yellow : Color.white.opacity(0.3), lineWidth: 2)
                        )
                    
                    // Show current exposure value if non-zero
                    if exposure != 0 {
                        Text(String(format: "%+.1f", exposure))
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.yellow)
                            .offset(y: 20)
                    }
                }
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showSlider = true
                        }
                    }
            )
        }
        .popover(isPresented: $showSlider, arrowEdge: .bottom) {
            VStack(spacing: 12) {
                HStack {
                    Text("Exposure")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                    Spacer()
                    Text(String(format: "%+.1f EV", exposure))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.yellow)
                }
                
                HStack(spacing: 8) {
                    Button(action: {
                        exposure = max(-2.0, exposure - 0.1)
                    }) {
                        Image(systemName: "minus")
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.gray.opacity(0.3))
                            .clipShape(Circle())
                    }
                    
                    Slider(value: $exposure, in: -2.0...2.0)
                        .tint(.yellow)
                    
                    Button(action: {
                        exposure = min(2.0, exposure + 0.1)
                    }) {
                        Image(systemName: "plus")
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.gray.opacity(0.3))
                            .clipShape(Circle())
                    }
                }
                
                Button(action: {
                    withAnimation {
                        exposure = 0.0
                    }
                }) {
                    Text("Reset to 0")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.3))
                        .clipShape(Capsule())
                }
            }
            .padding()
            .frame(width: 280)
            .background(.ultraThinMaterial)
            .presentationCompactAdaptation(.popover)
        }
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
                    // Show eyedropper indicator if mask sample is included
                    if preset.maskSample != nil {
                        Image(systemName: "eyedropper.halffull")
                            .font(.caption2)
                            .foregroundStyle(.green)
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
