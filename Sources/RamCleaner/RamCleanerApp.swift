import SwiftUI

@main
struct RamCleanerApp: App {

    @State private var monitor = RAMMonitor()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(monitor: monitor)
        } label: {
            MenuBarLabel(usagePercent: monitor.usagePercent)
        }
        .menuBarExtraStyle(.window)
    }
}

// แยก label ออกเป็น View ของตัวเอง
// SwiftUI จะ track @Observable ได้เสถียรเมื่อค่าถูกส่งผ่าน property ของ View
private struct MenuBarLabel: View {
    let usagePercent: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "cpu")
                .font(.system(size: 11))
            Text("\(usagePercent)%")
                .monospacedDigit()
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(color)
    }

    private var color: Color {
        if usagePercent < 60 { return .green }
        else if usagePercent < 80 { return .yellow }
        else { return .red }
    }
}
