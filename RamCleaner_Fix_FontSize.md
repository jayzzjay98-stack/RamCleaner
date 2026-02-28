# 🔤 RamCleaner — Increase Font Sizes

## เป้าหมาย
เพิ่มขนาด font ทุกจุดใน `MenuBarView.swift` โดย **ไม่ขยายหน้าต่าง (width คงที่ 280px)**

---

## แก้ไขทีละบรรทัด — `MenuBarView.swift`

### Header (chip name)
```swift
// บรรทัด: Image(systemName: "cpu")
// เดิม
.font(.system(size: 15))
// ใหม่
.font(.system(size: 17))

// บรรทัด: Text("\(monitor.chipName) · \(Int(monitor.totalGB))GB")
// เดิม
.font(.system(size: 13, weight: .bold))
// ใหม่
.font(.system(size: 15, weight: .bold))
```

### Main Display — MEMORY USAGE label
```swift
// เดิม
.font(.system(size: 8.5, weight: .medium, design: .monospaced))
// ใหม่
.font(.system(size: 10, weight: .medium, design: .monospaced))
```

### Main Display — ตัวเลข % ใหญ่
```swift
// เดิม
.font(.system(size: 40, weight: .bold, design: .rounded))
// ใหม่
.font(.system(size: 42, weight: .bold, design: .rounded))
```

### Main Display — % symbol
```swift
// เดิม
.font(.system(size: 18, weight: .regular))
// ใหม่
.font(.system(size: 20, weight: .regular))
```

### Main Display — "x.x GB / x.x GB"
```swift
// เดิม
.font(.system(size: 10, weight: .regular, design: .monospaced))
// ใหม่
.font(.system(size: 12, weight: .regular, design: .monospaced))
```

### Mini Ring — ตัวเลข FREE (ใน ZStack)
```swift
// เดิม
.font(.system(size: 11, weight: .bold, design: .monospaced))
// ใหม่
.font(.system(size: 13, weight: .bold, design: .monospaced))

// เดิม
.font(.system(size: 7, weight: .medium, design: .monospaced))  // "FREE"
// ใหม่
.font(.system(size: 9, weight: .medium, design: .monospaced))
```

### Stat Boxes — label (PRESSURE / SWAP / CACHED)
```swift
// เดิม
.font(.system(size: 8, weight: .medium, design: .monospaced))
// ใหม่
.font(.system(size: 10, weight: .medium, design: .monospaced))
```

### Stat Boxes — value (Medium / 324 MB / 3.0 GB)
```swift
// เดิม
.font(.system(size: 12, weight: .bold))
// ใหม่
.font(.system(size: 14, weight: .bold))
```

### Processes — "Scanning..."
```swift
// เดิม
.font(.system(size: 10, design: .monospaced))
// ใหม่
.font(.system(size: 12, design: .monospaced))
```

### Process Row — rank number (01, 02...)
```swift
// เดิม
.font(.system(size: 9, weight: .medium, design: .monospaced))
// ใหม่
.font(.system(size: 11, weight: .medium, design: .monospaced))
```

### Process Row — process name
```swift
// เดิม
.font(.system(size: 10, weight: .medium, design: .monospaced))
// ใหม่
.font(.system(size: 12, weight: .medium, design: .monospaced))
```

### Process Row — memory value (485 MB)
```swift
// เดิม
.font(.system(size: 9, weight: .medium, design: .monospaced))
// ใหม่
.font(.system(size: 11, weight: .medium, design: .monospaced))
```

### Action Buttons — icon (⟳ ◉)
```swift
// เดิม
Text(icon).font(.system(size: 15))
// ใหม่
Text(icon).font(.system(size: 17))
```

### Action Buttons — label (Quick Clean / Deep Clean)
```swift
// เดิม
Text(label).font(.system(size: 11, weight: .bold))
// ใหม่
Text(label).font(.system(size: 13, weight: .bold))
```

### Action Buttons — cleaning in progress text
```swift
// เดิม
.font(.system(size: 11, weight: .semibold))
// ใหม่
.font(.system(size: 13, weight: .semibold))
```

### Theme Section — "THEME" label
```swift
// เดิม
.font(.system(size: 8, weight: .medium, design: .monospaced))
// ใหม่
.font(.system(size: 10, weight: .medium, design: .monospaced))
```

### Theme Section — "9 / 10" หรือชื่อธีมที่เลือก
```swift
// เดิม
.font(.system(size: 8, design: .monospaced))
// ใหม่
.font(.system(size: 10, design: .monospaced))
```

### Theme Preset — ชื่อธีม (AMBER, MATRIX ฯลฯ)
```swift
// เดิม
.font(.system(size: 6, design: .monospaced))
// ใหม่
.font(.system(size: 8, design: .monospaced))
```

### Status Message
```swift
// เดิม
.font(.system(size: 9, weight: .medium, design: .monospaced))
// ใหม่
.font(.system(size: 11, weight: .medium, design: .monospaced))
```

### Footer — ⏻ icon
```swift
// เดิม
Text("⏻").font(.system(size: 9))
// ใหม่
Text("⏻").font(.system(size: 11))
```

### Footer — "Quit"
```swift
// เดิม
Text("Quit").font(.system(size: 10, weight: .medium, design: .monospaced))
// ใหม่
Text("Quit").font(.system(size: 12, weight: .medium, design: .monospaced))
```

### Footer — "REFRESH 2S · v1.0"
```swift
// เดิม
.font(.system(size: 8, design: .monospaced))
// ใหม่
.font(.system(size: 10, design: .monospaced))
```

---

## สรุป

- แก้แค่ **1 ไฟล์** คือ `MenuBarView.swift`
- เพิ่มทุก font **+2pt** สม่ำเสมอทั้งหมด
- **ไม่ต้องเปลี่ยน** `.frame(width: 280)` — ขนาดหน้าต่างคงเดิม
- **ไม่ต้องเปลี่ยน** padding, spacing หรือ layout อื่นใด
