# 🛠️ RamCleaner — Fix Prompt

โปรแกรมนี้เป็น macOS Menu Bar App เขียนด้วย Swift/SwiftUI
กรุณาแก้ไขโค้ดทั้งหมดตามรายการด้านล่างนี้:

---

## ✅ สิ่งที่ต้องแก้ไข

---

### 🔴 Fix 1 — `RAMMonitor.swift` : detectChipName ให้ค่าผิดบน Apple Silicon

**ปัญหา:**
`sysctlbyname("machdep.cpu.brand_string", ...)` ใช้ได้เฉพาะ Intel
บน Apple Silicon (M1/M2/M3/M4) จะ return empty string ทำให้แสดง "Apple Silicon" ตลอด

**วิธีแก้:**
ให้ detect chip name โดยอ่านจาก `sysctl("hw.model")` แล้ว map ค่า เช่น:
- "Mac14,3" → "Apple M2"
- "Mac15,x" → "Apple M3"
- "Mac16,x" → "Apple M4"

หรือใช้ `IORegistryEntry` เพื่ออ่าน chip name โดยตรง ถ้า fallback ไม่ได้ให้แสดง `hw.model` string แทน

---

### 🔴 Fix 2 — `RAMMonitor.swift` : fetchTopProcesses บน main thread (blocking UI)

**ปัญหา:**
```swift
process.waitUntilExit() // ← blocking call
```
`fetchTopProcesses()` ถูกเรียกจาก `refresh()` ซึ่ง Timer อาจ trigger บน main thread
ทำให้ UI กระตุกทุก 2 วินาที

**วิธีแก้:**
ให้ย้ายทั้ง `fetchTopProcesses()` ไปรันบน `DispatchQueue.global(qos: .background)`
แล้ว update `self.topProcesses` กลับมาบน `DispatchQueue.main.async { ... }`

---

### 🟡 Fix 3 — `RAMMonitor.swift` : freePercent ใน miniRing คำนวณผิด

**ปัญหา:**
```swift
let freePercent = max(0, 1.0 - Double(monitor.usagePercent) / 100.0)
```
`usagePercent` เป็น `Int` ทำให้มี rounding error วงแหวนไม่ตรงกับตัวเลขที่แสดง

**วิธีแก้:**
เปลี่ยนเป็น:
```swift
let freePercent = monitor.totalGB > 0 ? max(0.0, 1.0 - (monitor.usedGB / monitor.totalGB)) : 0.0
```

หมายเหตุ: โค้ดส่วนนี้อยู่ใน `MenuBarView.swift` ใน `miniRing` computed property

---

### 🟡 Fix 4 — `MenuBarView.swift` : segmentBar hardcode total = 16

**ปัญหา:**
```swift
let total = 16 // ← hardcoded ไม่ responsive
```

**วิธีแก้:**
ห่อ `segmentBar` ด้วย `GeometryReader` แล้วคำนวณ `total` จาก available width
เช่น `let total = max(8, Int(geometry.size.width / 12))`
เพื่อให้ segment bar ปรับตาม width อัตโนมัติ

---

### 🟡 Fix 5 — `RAMMonitor.swift` : deepCleanMemory ลบ Xcode DerivedData โดยไม่เช็คก่อน

**ปัญหา:**
```swift
let derivedData = "\(homeDir)/Library/Developer/Xcode/DerivedData"
if clearDirectory(derivedData) { ... }
```
ถ้า Xcode กำลัง build อยู่พอดี การลบ DerivedData จะทำให้ build พัง

**วิธีแก้:**
ก่อนลบ DerivedData ให้เช็คก่อนว่า Xcode ไม่ได้รันอยู่:
```swift
let xcodeIsRunning = NSWorkspace.shared.runningApplications
    .contains { $0.bundleIdentifier == "com.apple.dt.Xcode" }
if !xcodeIsRunning {
    // ค่อยลบ DerivedData
}
```

---

### 🟡 Fix 6 — `MenuBarView.swift` : cleaningInProgress ค้างถ้า user กด Cancel password dialog

**ปัญหา:**
ถ้า user กด Cancel ตอน AppleScript ขอ password
`cleaningInProgress` จะยังเป็น `true` ทำให้ปุ่ม Quick Clean / Deep Clean หายไปตลอด

**วิธีแก้:**
ใน `completion` handler ของทั้ง `cleanMemory` และ `deepCleanMemory`
ให้ set `cleaningInProgress = false` เสมอ ไม่ว่าจะ success หรือ fail

ใน `performClean` เพิ่ม timeout fallback:
```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
    if self.cleaningInProgress {
        self.cleaningInProgress = false
        self.statusMessage = "Timed out"
    }
}
```

---

### 🔵 Fix 7 — `Package.swift` : ชื่อ target สะกดผิด

**ปัญหา:**
```swift
name: "RamCleanner"  // ← มี n สองตัว
```

**วิธีแก้:**
เปลี่ยนเป็น `"RamCleaner"` ทุกที่ที่ปรากฏใน Package.swift
และ rename โฟลเดอร์ `Sources/RamCleanner/` → `Sources/RamCleaner/`
แล้วอัปเดต path ใน Package.swift ด้วย

---

## 📋 สรุปไฟล์ที่ต้องแก้

| ไฟล์ | Fix ที่ต้องแก้ |
|------|--------------|
| `RAMMonitor.swift` | Fix 1, 2, 3, 5, 6 |
| `MenuBarView.swift` | Fix 3, 4, 6 |
| `Package.swift` | Fix 7 |
| โฟลเดอร์ `Sources/RamCleanner/` | Fix 7 (rename) |

---

## ⚙️ ข้อมูลเพิ่มเติม

- macOS Deployment Target: **macOS 14+**
- Swift Tools Version: **5.9**
- Framework: **SwiftUI + AppKit**
- ใช้ `@Observable` macro (ต้องการ macOS 14+)
- App เป็น Menu Bar Only (ไม่มี Dock icon)
