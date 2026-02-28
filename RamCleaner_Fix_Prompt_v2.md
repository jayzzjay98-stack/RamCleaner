# 🛠️ RamCleaner — Fix Prompt v2

โปรแกรมนี้เป็น macOS Menu Bar App เขียนด้วย Swift/SwiftUI
กรุณาแก้ไขโค้ดตามรายการด้านล่างนี้ทุกข้อ:

---

## 🔴 Fix 1 — `Info.plist` : ชื่อยังสะกดผิดทุกบรรทัด

**ปัญหา:**
```xml
<string>com.justkay.RamCleanner</string>  ← ผิด
<string>RamCleanner</string>              ← ผิด (2 จุด)
<string>RamCleanner</string>              ← ผิด (CFBundleExecutable)
```
ถ้าปล่อยไว้ `@AppStorage` จะบันทึก theme ผิด bundle และ macOS จะ reject ตอน notarize

**วิธีแก้:**
เปลี่ยนทุก `RamCleanner` → `RamCleaner` ใน Info.plist:
```xml
<string>com.justkay.RamCleaner</string>
<string>RamCleaner</string>
<string>RamCleaner</string>
```

---

## 🔴 Fix 2 — `RAMMonitor.swift` : `detectChipName` mapping ผิด — Mac13 = M1 ไม่ใช่ M2

**ปัญหา:**
```swift
if model.hasPrefix("Mac13,") || model.hasPrefix("Mac14,") {
    self.chipName = "Apple M2"  // ← ผิด! Mac13 = M1 Pro/Max/Ultra
}
```

ข้อมูลจริงจาก Apple:
- `Mac12,x` = M1 (MacBook Air/Pro 13")
- `Mac13,1–4` = M1 Pro / M1 Max / M1 Ultra (MacBook Pro 14/16", Mac Studio)
- `Mac14,x` = M2 (MacBook Pro, Mac mini, MacBook Air)
- `Mac15,x` = M3
- `Mac16,x` = M4

**วิธีแก้:**
แทนที่ `detectChipName` ทั้งฟังก์ชันด้วยโค้ดนี้:

```swift
private func detectChipName() {
    var size: Int = 0
    sysctlbyname("hw.model", nil, &size, nil, 0)
    guard size > 0 else { return }
    var modelChars = [CChar](repeating: 0, count: size)
    guard sysctlbyname("hw.model", &modelChars, &size, nil, 0) == 0 else { return }
    let model = String(cString: modelChars)

    // Apple Silicon model mapping (verified against Apple's identifiers)
    switch true {
    case model.hasPrefix("Mac12,"):
        self.chipName = "Apple M1"
    case model.hasPrefix("Mac13,"):
        // Mac13,1 = MacBook Pro 14" M1 Pro
        // Mac13,2 = MacBook Pro 16" M1 Max
        // Mac13,3 = Mac Studio M1 Max
        // Mac13,4 = Mac Studio M1 Ultra
        self.chipName = "Apple M1"
    case model.hasPrefix("Mac14,"):
        self.chipName = "Apple M2"
    case model.hasPrefix("Mac15,"):
        self.chipName = "Apple M3"
    case model.hasPrefix("Mac16,"):
        self.chipName = "Apple M4"
    default:
        // Fallback: try Intel brand string
        var brandSize: Int = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &brandSize, nil, 0)
        if brandSize > 0 {
            var brandChars = [CChar](repeating: 0, count: brandSize)
            if sysctlbyname("machdep.cpu.brand_string", &brandChars, &brandSize, nil, 0) == 0 {
                let brand = String(cString: brandChars)
                if !brand.isEmpty {
                    self.chipName = brand
                    return
                }
            }
        }
        self.chipName = "Apple Silicon (\(model))"
    }
}
```

---

## 🔴 Fix 3 — `MenuBarView.swift` : `segmentBar` GeometryReader ได้ width = 0

**ปัญหา:**
`segmentBar` อยู่ใน `VStack` ภายใน `HStack` โดยไม่มี `.frame(maxWidth: .infinity)`
ทำให้ `GeometryReader` วัด width ได้ 0 → `total` จะได้ค่า minimum (8) ตลอด bar ไม่ stretch เต็ม

**วิธีแก้:**
ใน `mainDisplay` หา `segmentBar.padding(.top, 8)` แล้วเปลี่ยนเป็น:
```swift
segmentBar
    .frame(maxWidth: .infinity)
    .padding(.top, 8)
```

---

## 🔴 Fix 4 — `RAMMonitor.swift` : `systemCriticalNames` ยังมีชื่อเก่า `"ramcleanner"`

**ปัญหา:**
```swift
// Our app
"ramcleanner",  // ← ยังสะกดผิด ชื่อ process จริงคือ "ramcleaner"
```
ถ้าปล่อยไว้ app ตัวเองอาจถูก Deep Clean ฆ่าตัวเองได้

**วิธีแก้:**
เปลี่ยนเป็น:
```swift
// Our app
"ramcleaner",
```

---

## 🟡 Fix 5 — `RAMMonitor.swift` : `cleanMemory` คำนวณ freed ผิดเพราะ timing

**ปัญหา:**
```swift
self?.refresh()
// fetchTopProcesses() ใน refresh() รัน async background
// แต่ usedGB ยังไม่อัปเดตทัน ทำให้ freed = 0 เสมอ
let freed = max(0, usedBefore - (self?.usedGB ?? usedBefore))
```

**วิธีแก้:**
แทนที่ completion block ของ `cleanMemory` ด้วย:
```swift
DispatchQueue.main.async { [weak self] in
    if let error = errorDict {
        let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
        completion(false, message)
    } else {
        // เรียก fetchMemoryStats() โดยตรง (sync) แทน refresh() ที่มี async task ปน
        self?.fetchMemoryStats()
        self?.fetchMemoryPressure()
        let freed = max(0, usedBefore - (self?.usedGB ?? usedBefore))
        completion(true, String(format: "✅ Freed %.1f GB (cache cleared)", freed))
        // Fetch processes แยกหลังจากนั้น
        self?.fetchTopProcesses()
    }
}
```

หมายเหตุ: ต้องเปลี่ยน `fetchMemoryStats()` และ `fetchMemoryPressure()` จาก `private` เป็น `internal` (หรือลบ `private` ออก) เพื่อให้เรียกได้จาก completion block

ทำแบบเดียวกันใน `deepCleanMemory` ด้วย:
```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
    self?.fetchMemoryStats()
    self?.fetchMemoryPressure()
    let freed = max(0, usedBefore - (self?.usedGB ?? usedBefore))
    let summary = String(format: "✅ Deep clean done! Freed ~%.1f GB", freed)
    let details = summary + "\n" + steps.joined(separator: "\n")
    completion(true, details)
    self?.fetchTopProcesses()
}
```

---

## 🟡 Fix 6 — `RAMMonitor.swift` : Timer รันตลอดแม้ popup ปิด (เปลือง CPU/Battery)

**ปัญหา:**
Timer refresh ทุก 2 วินาทีแม้ user จะปิด popup ไปแล้ว

**วิธีแก้:**
เพิ่ม 2 ฟังก์ชันใน `RAMMonitor`:
```swift
func pauseTimer() {
    timer?.invalidate()
    timer = nil
}

func resumeTimer() {
    guard timer == nil else { return }
    refresh()
    startTimer()
}
```

แล้วใน `MenuBarView.swift` เพิ่ม modifier ใน `body`:
```swift
var body: some View {
    VStack(spacing: 0) {
        // ... เนื้อหาเดิม ...
    }
    .frame(width: 280)
    .background(theme.bgColor)
    .onAppear { monitor.resumeTimer() }
    .onDisappear { monitor.pauseTimer() }
}
```

---

## 📋 สรุปไฟล์ที่ต้องแก้

| ไฟล์ | Fix ที่ต้องแก้ |
|------|--------------|
| `Info.plist` | Fix 1 |
| `RAMMonitor.swift` | Fix 2, 4, 5, 6 |
| `MenuBarView.swift` | Fix 3, 6 |

---

## ⚙️ ข้อมูลเพิ่มเติม

- macOS Deployment Target: **macOS 14+**
- Swift Tools Version: **5.9**
- Framework: **SwiftUI + AppKit**
- ใช้ `@Observable` macro (macOS 14+)
- App เป็น Menu Bar Only (`LSUIElement = true`)
- โฟลเดอร์ source: `Sources/RamCleaner/`
