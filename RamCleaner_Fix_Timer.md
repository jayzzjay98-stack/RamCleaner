# 🛠️ RamCleaner — Fix Timer (Menu Bar Live Update)

## ปัญหา
ตอนนี้ตัวเลข % ใน menu bar icon ไม่อัปเดตเมื่อ popup ปิดอยู่
ต้องการให้ % อัปเดตทุก 3 วินาทีตลอดเวลา แม้ user จะไม่ได้เปิด popup

---

## วิธีแก้ — แยก Timer เป็น 2 ระดับ

### ใน `RAMMonitor.swift`

แทนที่ timer เดิมทั้งหมด (`private var timer: Timer?`) ด้วย 2 timers:

```swift
private var backgroundTimer: Timer?  // รันตลอด — อัปเดตเฉพาะ memory stats (% และ GB)
private var foregroundTimer: Timer?  // รันเฉพาะตอน popup เปิด — อัปเดตทุกอย่างรวม processes
```

เพิ่มฟังก์ชันดังนี้:

```swift
// เรียกตอน app เริ่ม — รัน background timer ตลอดเวลา
func startBackgroundTimer() {
    backgroundTimer?.invalidate()
    backgroundTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
        self?.fetchMemoryStats()
        self?.fetchMemoryPressure()
    }
}

// เรียกตอน popup เปิด — เพิ่ม foreground timer สำหรับ processes
func startForegroundTimer() {
    foregroundTimer?.invalidate()
    fetchTopProcesses() // โหลดทันทีเมื่อเปิด
    foregroundTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
        self?.fetchTopProcesses()
    }
}

// เรียกตอน popup ปิด — หยุดเฉพาะ foreground timer
func stopForegroundTimer() {
    foregroundTimer?.invalidate()
    foregroundTimer = nil
}
```

แก้ `init()` ให้เรียก `startBackgroundTimer()` แทน `startTimer()`:
```swift
init() {
    detectChipName()
    fetchMemoryStats()
    fetchMemoryPressure()
    fetchTopProcesses()
    startBackgroundTimer()
}
```

แก้ `deinit` ให้ invalidate ทั้งสอง timers:
```swift
deinit {
    backgroundTimer?.invalidate()
    foregroundTimer?.invalidate()
}
```

ลบฟังก์ชัน `startTimer()` และ `pauseTimer()` และ `resumeTimer()` เดิมออกทั้งหมด (ถ้ามี)

---

### ใน `MenuBarView.swift`

เพิ่ม `.onAppear` และ `.onDisappear` ใน `body`:

```swift
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
    .onAppear { monitor.startForegroundTimer() }
    .onDisappear { monitor.stopForegroundTimer() }
}
```

---

## ผลลัพธ์ที่ได้

| สถานะ | % ใน menu bar | รายการ processes |
|-------|--------------|-----------------|
| popup ปิด | ✅ อัปเดตทุก 3 วินาที | ⏸ หยุด (ประหยัด CPU) |
| popup เปิด | ✅ อัปเดตทุก 3 วินาที | ✅ อัปเดตทุก 3 วินาที |

---

## ⚙️ ข้อมูลเพิ่มเติม
- macOS Deployment Target: macOS 14+
- ใช้ `@Observable` macro
- `fetchMemoryStats()` และ `fetchMemoryPressure()` ต้องเป็น `internal` (ไม่ใช่ `private`) เพื่อให้เรียกได้จาก timer closure
- `fetchTopProcesses()` รันบน `DispatchQueue.global` อยู่แล้ว ไม่ต้องแก้
