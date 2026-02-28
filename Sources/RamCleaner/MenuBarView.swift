import SwiftUI

// MARK: - Theme

struct AppTheme {
    let name: String
    let icon: String
    let accent: Color
    let accentDim: Color
    let bgColor: Color
    let borderColor: Color
}

let appThemes: [AppTheme] = [
    AppTheme(name: "AMBER",  icon: "🟠", accent: Color(red: 1.0, green: 0.55, blue: 0.0),  accentDim: Color(red: 1.0, green: 0.55, blue: 0.0).opacity(0.1), bgColor: Color(red: 0.06, green: 0.047, blue: 0.03), borderColor: Color(red: 1.0, green: 0.55, blue: 0.0).opacity(0.22)),
    AppTheme(name: "MATRIX", icon: "🟢", accent: Color(red: 0.0, green: 1.0, blue: 0.53),  accentDim: Color(red: 0.0, green: 1.0, blue: 0.53).opacity(0.08), bgColor: Color(red: 0.027, green: 0.06, blue: 0.04), borderColor: Color(red: 0.0, green: 1.0, blue: 0.53).opacity(0.2)),
    AppTheme(name: "ARCTIC", icon: "🔵", accent: Color(red: 0.0, green: 0.78, blue: 1.0),  accentDim: Color(red: 0.0, green: 0.78, blue: 1.0).opacity(0.08), bgColor: Color(red: 0.027, green: 0.05, blue: 0.07), borderColor: Color(red: 0.0, green: 0.78, blue: 1.0).opacity(0.22)),
    AppTheme(name: "COSMIC", icon: "🟣", accent: Color(red: 0.66, green: 0.33, blue: 0.97), accentDim: Color(red: 0.66, green: 0.33, blue: 0.97).opacity(0.1), bgColor: Color(red: 0.047, green: 0.03, blue: 0.07), borderColor: Color(red: 0.66, green: 0.33, blue: 0.97).opacity(0.22)),
    AppTheme(name: "ROSE",   icon: "🩷", accent: Color(red: 0.98, green: 0.44, blue: 0.52), accentDim: Color(red: 0.98, green: 0.44, blue: 0.52).opacity(0.1), bgColor: Color(red: 0.07, green: 0.03, blue: 0.06), borderColor: Color(red: 0.98, green: 0.44, blue: 0.52).opacity(0.22)),
    AppTheme(name: "GOLD",   icon: "🌟", accent: Color(red: 0.96, green: 0.77, blue: 0.09), accentDim: Color(red: 0.96, green: 0.77, blue: 0.09).opacity(0.1), bgColor: Color(red: 0.067, green: 0.055, blue: 0.016), borderColor: Color(red: 0.96, green: 0.77, blue: 0.09).opacity(0.22)),
    AppTheme(name: "CYAN",   icon: "🩵", accent: Color(red: 0.0, green: 0.9, blue: 0.8),   accentDim: Color(red: 0.0, green: 0.9, blue: 0.8).opacity(0.08), bgColor: Color(red: 0.02, green: 0.06, blue: 0.055), borderColor: Color(red: 0.0, green: 0.9, blue: 0.8).opacity(0.22)),
    AppTheme(name: "LAVA",   icon: "🔴", accent: Color(red: 1.0, green: 0.23, blue: 0.36),  accentDim: Color(red: 1.0, green: 0.23, blue: 0.36).opacity(0.1), bgColor: Color(red: 0.067, green: 0.02, blue: 0.02), borderColor: Color(red: 1.0, green: 0.23, blue: 0.36).opacity(0.22)),
    AppTheme(name: "LIME",   icon: "💚", accent: Color(red: 0.52, green: 0.8, blue: 0.09),  accentDim: Color(red: 0.52, green: 0.8, blue: 0.09).opacity(0.1), bgColor: Color(red: 0.035, green: 0.06, blue: 0.02), borderColor: Color(red: 0.52, green: 0.8, blue: 0.09).opacity(0.22)),
    AppTheme(name: "SILVER", icon: "🤍", accent: Color(red: 0.69, green: 0.72, blue: 0.8),  accentDim: Color(red: 0.69, green: 0.72, blue: 0.8).opacity(0.1), bgColor: Color(red: 0.05, green: 0.05, blue: 0.06), borderColor: Color(red: 0.69, green: 0.72, blue: 0.8).opacity(0.2)),
]

// MARK: - Menu Bar View

struct MenuBarView: View {

    let monitor: RAMMonitor

    @State private var cleaningInProgress = false
    @State private var cleaningType: String = ""
    @State private var statusMessage: String?
    @State private var statusIsSuccess = false
    @AppStorage("selectedTheme") private var selectedTheme: Int = 0

    private var theme: AppTheme { appThemes[selectedTheme] }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            mainDisplay
            statsGrid
            dividerLine("PROCESSES")
            processesSection
            actionButtons
            themeSection
            footerSection
        }
        .frame(width: 280)
        .background(theme.bgColor)
        .onAppear { monitor.resumeTimer() }
        .onDisappear { monitor.pauseTimer() }
    }

    // MARK: - Header (centered chip name + icon)

    private var headerSection: some View {
        HStack(spacing: 8) {
            Spacer()
            Image(systemName: "cpu")
                .font(.system(size: 15))
                .foregroundStyle(theme.accent)
            Text("\(monitor.chipName) · \(Int(monitor.totalGB))GB")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.05)).frame(height: 0.5)
        }
    }

    // MARK: - Main Display

    private var mainDisplay: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text("MEMORY USAGE")
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(0.8)
                    .padding(.bottom, 4)

                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(monitor.usagePercent)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.accent)
                        .shadow(color: theme.accent.opacity(0.25), radius: 10)
                        .monospacedDigit()
                    Text("%")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(theme.accent.opacity(0.5))
                }

                Text(String(format: "%.1f GB / %.1f GB", monitor.usedGB, monitor.totalGB))
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 2)

                segmentBar
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }

            Spacer()
            miniRing
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    // MARK: - Segment Bar

    private var segmentBar: some View {
        GeometryReader { geometry in
            let total = max(8, Int(geometry.size.width / 12))
            let filled = Int(Double(monitor.usagePercent) / 100.0 * Double(total))
            
            HStack(spacing: 1.5) {
                ForEach(0..<total, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(
                            i < filled ? theme.accent :
                            i == filled ? theme.accent.opacity(0.35) :
                            Color.white.opacity(0.05)
                        )
                        .frame(height: segmentHeight(i, total: total))
                }
            }
        }
        .frame(height: 14)
    }

    private func segmentHeight(_ i: Int, total: Int) -> CGFloat {
        let mid = Double(total) / 2.0
        return CGFloat(14.0 - abs(Double(i) - mid) * 0.8)
    }

    // MARK: - Mini Ring

    private var miniRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.05), lineWidth: 5)
                .frame(width: 52, height: 52)

            let freePercent = monitor.totalGB > 0 ? max(0.0, 1.0 - (monitor.usedGB / monitor.totalGB)) : 0.0
            Circle()
                .trim(from: 0, to: freePercent)
                .stroke(theme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .butt))
                .frame(width: 52, height: 52)
                .rotationEffect(.degrees(-90))
                .shadow(color: theme.accent.opacity(0.25), radius: 3)

            VStack(spacing: 0) {
                Text(String(format: "%.1f", max(0, monitor.totalGB - monitor.usedGB)))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text("FREE")
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        HStack(spacing: 4) {
            statBox(label: "PRESSURE", value: monitor.pressure.rawValue, isOk: monitor.pressure == .low)
            statBox(label: "SWAP", value: formatSwap(monitor.swapUsedMB), isOk: false)
            statBox(label: "CACHED", value: String(format: "%.1f GB", monitor.cachedGB), isOk: false)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    private func formatSwap(_ mb: Double) -> String {
        if mb < 1 { return "0 MB" }
        if mb >= 1024 { return String(format: "%.1f GB", mb / 1024.0) }
        return String(format: "%.0f MB", mb)
    }

    private func statBox(label: String, value: String, isOk: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .tracking(0.5)
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isOk ? Color(red: 0.29, green: 0.87, blue: 0.5) : .white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        )
    }

    // MARK: - Divider

    private func dividerLine(_ label: String) -> some View {
        ZStack {
            Rectangle().fill(Color.white.opacity(0.05)).frame(height: 0.5)
            Text(label)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .tracking(1)
                .padding(.horizontal, 8)
                .background(theme.bgColor)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
    }

    // MARK: - Processes

    private var processesSection: some View {
        VStack(spacing: 1) {
            if monitor.topProcesses.isEmpty {
                HStack(spacing: 5) {
                    ProgressView().controlSize(.small)
                    Text("Scanning...")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.vertical, 4)
            } else {
                let maxMem = monitor.topProcesses.first?.memoryMB ?? 1
                ForEach(Array(monitor.topProcesses.enumerated()), id: \.element.id) { i, p in
                    processRow(p, rank: i + 1, maxMem: maxMem)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    private func processRow(_ p: ProcessInfo, rank: Int, maxMem: Double) -> some View {
        HStack(spacing: 6) {
            Text(String(format: "%02d", rank))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.accent.opacity(0.5))
                .frame(width: 14, alignment: .leading)

            Text(p.name)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1).truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1.5).fill(Color.white.opacity(0.06)).frame(width: 40, height: 2.5)
                RoundedRectangle(cornerRadius: 1.5).fill(theme.accent.opacity(0.7))
                    .frame(width: max(2, 40 * p.memoryMB / maxMem), height: 2.5)
            }
            .frame(width: 40)

            Text(formatMemory(p.memoryMB))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 48, alignment: .trailing)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
    }

    // MARK: - Buttons (centered, no shortcut keys)

    private var actionButtons: some View {
        HStack(spacing: 6) {
            if cleaningInProgress {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small).tint(theme.accent)
                    Text(cleaningType)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.accent)
                }
                .frame(maxWidth: .infinity).frame(height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 8).fill(theme.accentDim)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.borderColor, lineWidth: 0.5))
                )
            } else {
                cleanButton(icon: "⟳", label: "Quick Clean") { performClean(deep: false) }
                    .keyboardShortcut("c", modifiers: [.command])
                cleanButton(icon: "◉", label: "Deep Clean") { performClean(deep: true) }
                    .keyboardShortcut("d", modifiers: [.command])
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    private func cleanButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(icon).font(.system(size: 15)).foregroundStyle(theme.accent)
                Text(label).font(.system(size: 11, weight: .bold)).foregroundStyle(.white.opacity(0.9))
            }
            .foregroundStyle(theme.accent)
            .frame(maxWidth: .infinity).frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 8).fill(theme.accentDim)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.borderColor, lineWidth: 0.5))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Status + Theme

    private var themeSection: some View {
        VStack(spacing: 4) {
            if let msg = statusMessage {
                Text(msg.components(separatedBy: "\n").first ?? msg)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(statusIsSuccess ? Color(red: 0.29, green: 0.87, blue: 0.5) : .red)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
            }

            Rectangle().fill(Color.white.opacity(0.05)).frame(height: 0.5)

            HStack {
                Text("THEME")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6)).tracking(0.8)
                Spacer()
                Text("\(selectedTheme + 1) / \(appThemes.count)")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(theme.accent.opacity(0.6))
            }
            .padding(.horizontal, 12)

            let cols = 5
            VStack(spacing: 3) {
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(0..<cols, id: \.self) { col in
                            let i = row * cols + col
                            if i < appThemes.count {
                                themePreset(appThemes[i], index: i)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 6)
    }

    private func themePreset(_ t: AppTheme, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTheme = index }
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(t.accent.opacity(0.15))
                        .frame(width: 32, height: 24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(index == selectedTheme ? Color.white : .clear, lineWidth: 1.5)
                        )
                    Text(t.icon).font(.system(size: 10))
                }
                Text(t.name)
                    .font(.system(size: 6, design: .monospaced))
                    .foregroundStyle(index == selectedTheme ? .white.opacity(0.8) : .white.opacity(0.2))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack(spacing: 4) {
                    Text("⏻").font(.system(size: 9))
                    Text("Quit").font(.system(size: 10, weight: .medium, design: .monospaced))
                }
                .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q", modifiers: [.command])

            Spacer()

            Text("REFRESH 2S · v1.0")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.05)).frame(height: 0.5)
        }
    }

    // MARK: - Helpers

    private func formatMemory(_ mb: Double) -> String {
        mb >= 1024 ? String(format: "%.1f GB", mb / 1024.0) : String(format: "%.0f MB", mb)
    }

    private func performClean(deep: Bool) {
        cleaningInProgress = true
        cleaningType = deep ? "Deep cleaning..." : "Quick cleaning..."
        statusMessage = nil
        
        let action = deep ? monitor.deepCleanMemory : monitor.cleanMemory
        
        // Timeout mechanism: in case user cancels or AppleScript hangs
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
            if self.cleaningInProgress {
                self.cleaningInProgress = false
                self.statusMessage = "Timed out"
                self.statusIsSuccess = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.statusMessage = nil }
            }
        }
        
        action { success, message in
            Task { @MainActor in
                // Only update if it hasn't timed out
                if cleaningInProgress || statusMessage == nil {
                    cleaningInProgress = false
                    statusIsSuccess = success
                    statusMessage = message
                    DispatchQueue.main.asyncAfter(deadline: .now() + 6) { statusMessage = nil }
                }
            }
        }
    }
}
