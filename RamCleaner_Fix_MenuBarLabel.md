# 🛠️ RamCleaner — Fix Menu Bar Live Update

## ปัญหา
ตัวเลข % ใน menu bar icon ไม่อัปเดต แม้ backgroundTimer จะทำงานถูกต้องแล้ว
สาเหตุคือ SwiftUI ไม่ track `@Observable` ใน label ของ `MenuBarExtra` อย่างเสถียร
เพราะ label ไม่ใช่ View ปกติ ทำให้ re-render ไม่เกิดขึ้นเมื่อ usagePercent เปลี่ยน

---

## วิธีแก้ — แก้แค่ 1 ไฟล์คือ `RamCleanerApp.swift`

แทนที่โค้ดทั้งหมดใน `RamCleanerApp.swift` ด้วย:

```swift
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
```

---

## สาเหตุที่แก้แบบนี้

`MenuBarExtra { } label: { }` ใน SwiftUI มีพฤติกรรมพิเศษ —
SwiftUI จะไม่ subscribe การเปลี่ยนแปลงของ `@Observable` ใน label closure
อย่างเสถียรเหมือน View ปกติ

การแยก label ออกเป็น `MenuBarLabel: View` แล้วส่ง `usagePercent: Int` เข้าไปตรงๆ
บังคับให้ SwiftUI สร้าง observation dependency อย่างถูกต้อง
ทำให้ re-render ทุกครั้งที่ `usagePercent` เปลี่ยนค่า

---

## ผลลัพธ์
- % ใน menu bar อัปเดต **ทุก 2 วินาที ตลอดเวลา** ไม่ว่าจะเปิด popup หรือไม่
- สีเปลี่ยนตาม threshold (🟢 <60% / 🟡 <80% / 🔴 ≥80%) แบบ real-time

---

## ⚙️ ข้อมูลเพิ่มเติม
- macOS Deployment Target: macOS 14+
- ใช้ `@Observable` macro
- ไม่ต้องแก้ไฟล์อื่นใด
