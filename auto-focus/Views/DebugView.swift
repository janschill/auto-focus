//
//  DebugMenuView.swift
//  auto-focus
//
//  Created for development debugging purposes
//

import SwiftUI

struct DebugMenuView: View {
    @EnvironmentObject var focusManager: FocusManager
    @State private var daysToGenerate: Int = 30
    @State private var sessionsPerDay: Int = 5
    @State private var avgSessionLength: Int = 25
    @State private var showingConfirmationAlert = false
    @State private var alertType: AlertType = .clearData
    
    enum AlertType {
        case clearData
        case addData
    }
    
    var body: some View {
        #if DEBUG
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "ladybug.fill")
                    .foregroundColor(.orange)
                Text("Debug Options")
                    .font(.headline)
            }
            .padding(.bottom, 4)
            
            // Sample data configuration controls
            GroupBox("Sample Data Generator") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Days:")
                            .frame(width: 80, alignment: .leading)
                        Slider(value: Binding(
                            get: { Double(daysToGenerate) },
                            set: { daysToGenerate = Int($0) }
                        ), in: 7...90, step: 1)
                        Text("\(daysToGenerate)")
                            .frame(width: 30)
                    }
                    
                    HStack {
                        Text("Sessions/day:")
                            .frame(width: 80, alignment: .leading)
                        Slider(value: Binding(
                            get: { Double(sessionsPerDay) },
                            set: { sessionsPerDay = Int($0) }
                        ), in: 1...15, step: 1)
                        Text("\(sessionsPerDay)")
                            .frame(width: 30)
                    }
                    
                    HStack {
                        Text("Avg. mins:")
                            .frame(width: 80, alignment: .leading)
                        Slider(value: Binding(
                            get: { Double(avgSessionLength) },
                            set: { avgSessionLength = Int($0) }
                        ), in: 5...60, step: 1)
                        Text("\(avgSessionLength)")
                            .frame(width: 30)
                    }
                    
                    // Action buttons
                    HStack(spacing: 12) {
                        Button("Generate Data") {
                            alertType = .addData
                            showingConfirmationAlert = true
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Clear All Data") {
                            alertType = .clearData
                            showingConfirmationAlert = true
                        }
                        .foregroundColor(.red)
                    }
                    .padding(.top, 8)
                }
                .padding(10)
            }
            
            Text("Note: These options are only available in debug builds")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .alert(isPresented: $showingConfirmationAlert) {
            switch alertType {
            case .clearData:
                return Alert(
                    title: Text("Clear All Data"),
                    message: Text("This will delete all focus sessions. This action cannot be undone."),
                    primaryButton: .destructive(Text("Clear")) {
                        focusManager.clearAllSessions()
                    },
                    secondaryButton: .cancel()
                )
            case .addData:
                return Alert(
                    title: Text("Generate Sample Data"),
                    message: Text("This will add \(daysToGenerate) days of sample data with ~\(sessionsPerDay) sessions per day."),
                    primaryButton: .default(Text("Generate")) {
                        let sessions = SampleDataGenerator.shared.generateSampleSessions(
                            days: daysToGenerate,
                            sessionsPerDay: sessionsPerDay,
                            avgSessionLength: TimeInterval(avgSessionLength * 60)
                        )
                        focusManager.addSampleSessions(sessions)
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        #else
        EmptyView()
        #endif
    }
}

#if DEBUG
// Preview provider for SwiftUI canvas
struct DebugMenuView_Previews: PreviewProvider {
    static var previews: some View {
        DebugMenuView()
            .environmentObject(FocusManager())
            .frame(width: 500)
            .padding()
    }
}
#endif
