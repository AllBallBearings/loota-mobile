import SwiftUI
import CoreLocation

struct ExportedFile: Identifiable {
    let id = UUID()
    let filename: String
    let content: String
    let format: String
    let exportDate: Date
    let url: URL?
}

struct SurveyQuestView: View {
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @StateObject private var surveyManager = SurveyManager()
    @StateObject private var locationManager = LocationManager()
    
    @State private var showingExportSheet = false
    @State private var exportedFiles: [ExportedFile] = []
    @State private var showingShareSheet = false
    @State private var fileToShare: ExportedFile?
    @State private var showingPathVisualization = false
    
    var body: some View {
        ZStack {
                // Background
                Color.black.opacity(0.9)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Fixed top section
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Survey Quest")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Track your route with elevation data")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 20)
                        
                        // Status Card
                        StatusCardView(surveyManager: surveyManager)
                        
                        // Control Buttons
                        ControlButtonsView(
                            surveyManager: surveyManager,
                            locationManager: locationManager,
                            showingExportSheet: $showingExportSheet,
                            showingPathVisualization: $showingPathVisualization,
                            onClearSurvey: {
                                surveyManager.clearSurvey()
                                exportedFiles.removeAll()
                            }
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Flexible data points section
                    DataPointsDisplayView(surveyManager: surveyManager)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    
                    // Exported files section
                    if !exportedFiles.isEmpty {
                        ExportedFilesView(
                            exportedFiles: exportedFiles,
                            onShareFile: { file in
                                fileToShare = file
                            },
                            onDeleteFile: { file in
                                exportedFiles.removeAll { $0.id == file.id }
                            }
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                    
                    Spacer(minLength: 20)
                }
            }
            .navigationBarBackButtonHidden(false)
            .navigationTitle("Survey Quest")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                locationManager.requestAuthorization()
                locationManager.startUpdating()
            }
            .onDisappear {
                if surveyManager.isActive {
                    surveyManager.stopSurvey()
                }
            }
            .confirmationDialog("Export Data", isPresented: $showingExportSheet, titleVisibility: .visible) {
                Button("Export as CSV") {
                    exportFile(format: "CSV")
                }
                Button("Export as JSON") {
                    exportFile(format: "JSON")
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Choose export format")
            }
            .sheet(item: $fileToShare) { file in
                if let url = file.url {
                    ShareSheet(items: [url])
                }
            }
            .fullScreenCover(isPresented: $showingPathVisualization) {
                PathVisualizationView(surveyData: surveyManager.dataPoints)
            }
    }
    
    private func exportFile(format: String) {
        print("🗂️ exportFile called with format: \(format)")
        print("🗂️ Data points count: \(surveyManager.dataPoints.count)")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        let dateString = dateFormatter.string(from: Date())
        
        let filename = "Quest Path \(dateString)"
        let content: String
        let fileExtension: String
        
        switch format {
        case "CSV":
            content = surveyManager.exportAsCSV()
            fileExtension = "csv"
            print("🗂️ Generated CSV content: \(content.prefix(100))...")
        case "JSON":
            content = surveyManager.exportAsJSON()
            fileExtension = "json"
            print("🗂️ Generated JSON content: \(content.prefix(100))...")
        default:
            print("🗂️ Unknown format: \(format)")
            return
        }
        
        // Save to temporary directory
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("\(filename).\(fileExtension)")
        
        print("🗂️ Attempting to save to: \(fileURL.path)")
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            
            let exportedFile = ExportedFile(
                filename: "\(filename).\(fileExtension)",
                content: content,
                format: format,
                exportDate: Date(),
                url: fileURL
            )
            
            exportedFiles.append(exportedFile)
            print("🗂️ File exported successfully: \(fileURL.path)")
            print("🗂️ Total exported files: \(exportedFiles.count)")
            
        } catch {
            print("🗂️ Error saving file: \(error)")
        }
    }
}

struct ExportedFilesView: View {
    let exportedFiles: [ExportedFile]
    let onShareFile: (ExportedFile) -> Void
    let onDeleteFile: (ExportedFile) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exported Files")
                .font(.headline)
                .foregroundColor(.white)
            
            ForEach(exportedFiles) { file in
                ExportedFileRowView(
                    file: file,
                    onShare: { onShareFile(file) },
                    onDelete: { onDeleteFile(file) }
                )
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.6))
        .cornerRadius(12)
    }
}

struct ExportedFileRowView: View {
    let file: ExportedFile
    let onShare: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(file.filename)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                HStack {
                    Text(file.format)
                        .font(.caption)
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.yellow.opacity(0.2))
                        .cornerRadius(4)
                    
                    Text(formatExportDate(file.exportDate))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
    }
    
    private func formatExportDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct StatusCardView: View {
    @ObservedObject var surveyManager: SurveyManager
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(surveyManager.isActive ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)
                
                Text(surveyManager.isActive ? "Recording" : "Stopped")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                if surveyManager.isActive {
                    Text(surveyManager.elapsedTimeString)
                        .font(.subheadline)
                        .foregroundColor(.yellow)
                }
            }
            
            // Sampling interval picker (only show when not recording)
            if !surveyManager.isActive {
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                VStack(spacing: 8) {
                    Text("Sampling Interval")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Picker("Sampling Interval", selection: $surveyManager.samplingInterval) {
                        ForEach(SurveyManager.SamplingInterval.allCases, id: \.self) { interval in
                            Text(interval.displayName).tag(interval)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .disabled(surveyManager.isActive)
                    .foregroundColor(.white)
                    .accentColor(.yellow)
                }
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            VStack(spacing: 12) {
                // First row of stats
                HStack {
                    StatItemView(title: "Points", value: "\(surveyManager.dataPoints.count)")
                    Spacer()
                    StatItemView(title: "Distance Traveled", value: String(format: "%.1f ft", surveyManager.totalDistance * 3.28084))
                    Spacer()
                    StatItemView(title: "Interval", value: surveyManager.samplingInterval.displayName)
                }
                
                // Second row of stats
                HStack {
                    let distanceFromOrigin = surveyManager.dataPoints.last?.distanceFromOrigin ?? 0
                    StatItemView(title: "From Start", value: String(format: "%.1f ft", distanceFromOrigin * 3.28084))
                    Spacer()
                    StatItemView(title: "Last Elevation", value: surveyManager.lastElevation != nil ? String(format: "%.1f ft", surveyManager.lastElevation! * 3.28084) : "N/A")
                    Spacer()
                    let elevationChange = calculateElevationChange(surveyManager.dataPoints)
                    StatItemView(title: "Elevation Δ", value: String(format: "%.1f ft", elevationChange * 3.28084))
                }
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.6))
        .cornerRadius(12)
    }
}

struct StatItemView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.headline)
                .foregroundColor(.white)
        }
    }
}

struct ControlButtonsView: View {
    @ObservedObject var surveyManager: SurveyManager
    @ObservedObject var locationManager: LocationManager
    @Binding var showingExportSheet: Bool
    @Binding var showingPathVisualization: Bool
    let onClearSurvey: () -> Void
    
    var body: some View {
        VStack(spacing: 15) {
            // First row: Start/Stop, Export, and View Quest
            HStack(spacing: 12) {
                Button(action: {
                    if surveyManager.isActive {
                        surveyManager.stopSurvey()
                    } else {
                        surveyManager.startSurvey(locationManager: locationManager)
                    }
                }) {
                    HStack {
                        Image(systemName: surveyManager.isActive ? "stop.fill" : "play.fill")
                            .font(.title2)
                        Text(surveyManager.isActive ? "Stop" : "Start")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(surveyManager.isActive ? Color.red : Color.green)
                    .cornerRadius(8)
                }
                .disabled(locationManager.currentLocation == nil)
                
                Button(action: {
                    print("🗂️ Export button tapped!")
                    // Stop recording when exporting
                    if surveyManager.isActive {
                        print("🗂️ Stopping active survey")
                        surveyManager.stopSurvey()
                    }
                    print("🗂️ Setting showingExportSheet to true")
                    showingExportSheet = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                        Text("Export")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                .disabled(surveyManager.dataPoints.isEmpty)
                
                Button(action: {
                    print("🎮 View Quest button tapped!")
                    showingPathVisualization = true
                }) {
                    HStack {
                        Image(systemName: "view.3d")
                            .font(.title2)
                        Text("View Quest")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.purple)
                    .cornerRadius(8)
                }
                .disabled(surveyManager.dataPoints.count < 2)
            }
            
            // Second row: Clear button (only show if there's data)
            if !surveyManager.dataPoints.isEmpty {
                Button(action: onClearSurvey) {
                    HStack {
                        Image(systemName: "trash")
                            .font(.title2)
                        Text("Clear Survey")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(8)
                }
            }
        }
    }
}

struct DataPointsDisplayView: View {
    @ObservedObject var surveyManager: SurveyManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Points")
                .font(.headline)
                .foregroundColor(.white)
            
            if surveyManager.dataPoints.isEmpty {
                Text("No data points recorded yet")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(surveyManager.dataPoints.enumerated()), id: \.offset) { index, point in
                                DataPointRowView(
                                    index: index + 1, 
                                    point: point,
                                    isLatest: index == surveyManager.dataPoints.count - 1
                                )
                                .id(index) // Give each row a unique ID for scrolling
                            }
                        }
                        .padding(.bottom, 8) // Add some padding at bottom
                    }
                    .frame(maxHeight: .infinity)
                    .onChange(of: surveyManager.dataPoints.count) { oldCount, newCount in
                        // Auto-scroll to the latest entry when new data is added
                        if newCount > oldCount && newCount > 0 {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                proxy.scrollTo(newCount - 1, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.6))
        .cornerRadius(12)
    }
}

struct DataPointRowView: View {
    let index: Int
    let point: SurveyDataPoint
    let isLatest: Bool
    
    var body: some View {
        HStack {
            Text("\(index)")
                .font(.caption)
                .foregroundColor(isLatest ? .green : .yellow)
                .frame(width: 30, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%.6f, %.6f", point.latitude, point.longitude))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(isLatest ? .green : .white)
                
                HStack {
                    Text(String(format: "%.1f ft", point.elevation * 3.28084))
                        .font(.caption)
                        .foregroundColor(isLatest ? .green : .gray)
                    
                    Spacer()
                    
                    Text(formatTime(point.timestamp))
                        .font(.caption)
                        .foregroundColor(isLatest ? .green : .gray)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isLatest ? Color.green.opacity(0.2) : Color.black.opacity(0.3))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isLatest ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}

// Helper function to calculate elevation change
func calculateElevationChange(_ dataPoints: [SurveyDataPoint]) -> Double {
    guard dataPoints.count >= 2 else { return 0.0 }
    
    let firstElevation = dataPoints.first?.barometricElevation ?? dataPoints.first?.elevation ?? 0.0
    let lastElevation = dataPoints.last?.barometricElevation ?? dataPoints.last?.elevation ?? 0.0
    
    return lastElevation - firstElevation
}

#Preview {
    SurveyQuestView()
}