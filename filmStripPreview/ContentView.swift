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
                
                // Camera preview with film negative effect (LARGER)
                if let image = cameraManager.processedImage {
                    Image(image, scale: 1.0, label: Text("Film Preview"))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 8)
                } else {
                    ProgressView("Starting camera...")
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Tap indicator when controls are hidden
                if !showControls {
                    HStack {
                        Spacer()
                        Image(systemName: "chevron.up")
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.bottom, 8)
                        Spacer()
                    }
                }
            }
            
            // Sliding control tray from bottom
            VStack {
                Spacer()
                
                VStack(spacing: 0) {
                    // Handle to drag/tap
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            showControls.toggle()
                        }
                    }) {
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.white.opacity(0.5))
                                .frame(width: 40, height: 5)
                                .padding(.top, 8)
                            
                            Image(systemName: showControls ? "chevron.down" : "chevron.up")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.bottom, 4)
                        }
                    }
                    
                    if showControls {
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
                        .padding(.vertical, 12)
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
