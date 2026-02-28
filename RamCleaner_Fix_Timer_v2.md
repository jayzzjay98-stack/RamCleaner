# 🛠️ RamCleaner — Fix Timer Live Update

## ปัญหา
ตัวเลข % ใน menu bar icon บางทีไม่อัปเดต เพราะ `Timer.scheduledTimer`
ถูกสร้างโดยไม่การันตีว่าอยู่บน main thread
Timer ของ macOS ต้องรันบน **main RunLoop** เท่านั้น ถึงจะ fire ได้ทุกครั้ง

---

## วิธีแก้ — แก้แค่ 1 ไฟล์คือ `RAMMonitor.swift`

### แทนที่ฟังก์ชัน `startBackgroundTimer()` เดิมด้วย:

```swift
func startBackgroundTimer() {
    // Must run on main thread — Timer requires main RunLoop to fire reliably
    if Thread.isMainThread {
        backgroundTimer?.invalidate()
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.fetchMemoryStats()
            self?.fetchMemoryPressure()
        }
        RunLoop.main.add(backgroundTimer!, forMode: .common)
    } else {
        DispatchQueue.main.async { [weak self] in
            self?.startBackgroundTimer()
        }
    }
}
```

### แทนที่ฟังก์ชัน `startForegroundTimer()` เดิมด้วย:

```swift
func startForegroundTimer() {
    DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        self.foregroundTimer?.invalidate()
        self.fetchTopProcesses()
        self.foregroundTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.fetchTopProcesses()
        }
        RunLoop.main.add(self.foregroundTimer!, forMode: .common)
    }
}
```

---

## สิ่งที่เปลี่ยน

| จุด | เดิม | ใหม่ |
|-----|------|------|
| interval | 3.0 วินาที | 2.0 วินาที |
| thread safety | ไม่การันตี | force main thread เสมอ |
| RunLoop mode | default | `.common` (ทำงานแม้ขณะ track เมาส์) |

## ผลลัพธ์
- % ใน menu bar อัปเดตทุก **2 วินาที ตลอดเวลา** ไม่ว่าจะเปิด popup หรือไม่
- ไม่มีกระตุก ไม่มีหยุดอัปเดตกลางคัน
