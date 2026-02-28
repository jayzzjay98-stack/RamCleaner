import SwiftUI

@main
struct RamCleanerApp: App {

    @State private var monitor = RAMMonitor()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(monitor: monitor)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)
    }

    // MARK: - Menu Bar Label

    private var menuBarLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "cpu")
                .font(.system(size: 11))
            Text("\(monitor.usagePercent)%")
                .monospacedDigit()
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(menuBarColor)
    }

    private var menuBarColor: Color {
        if monitor.usagePercent < 60 {
            return .green
        } else if monitor.usagePercent < 80 {
            return .yellow
        } else {
            return .red
        }
    }
}
