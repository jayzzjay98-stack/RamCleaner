# 🎨 RamCleaner — Redesign Theme Picker

## เป้าหมาย
ออกแบบ Theme Picker ใหม่ให้ดูโปรและสวยงามขึ้น
แก้แค่ **1 ไฟล์** คือ `MenuBarView.swift`

---

## การเปลี่ยนแปลงทั้งหมด

### 1. ลบ `icon` ออกจาก `AppTheme` struct
```swift
// เดิม
struct AppTheme {
    let name: String
    let icon: String   // ← ลบออก
    let accent: Color
    let accentDim: Color
    let bgColor: Color
    let borderColor: Color
}

// ใหม่
struct AppTheme {
    let name: String
    let accent: Color
    let accentDim: Color
    let bgColor: Color
    let borderColor: Color
}
```

### 2. ลบ `icon:` ออกจาก `appThemes` array ทุก entry
```swift
// เดิม (ตัวอย่าง)
AppTheme(name: "AMBER", icon: "🟠", accent: ...)

// ใหม่
AppTheme(name: "AMBER", accent: ...)
```
ทำแบบนี้ทุก theme ทั้ง 10 ตัว

---

### 3. แทนที่ฟังก์ชัน `themeSection` ทั้งหมดด้วย:

```swift
private var themeSection: some View {
    VStack(spacing: 0) {
        if let msg = statusMessage {
            Text(msg.components(separatedBy: "\n").first ?? msg)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(statusIsSuccess ? Color(red: 0.29, green: 0.87, blue: 0.5) : .red)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
        }

        Rectangle().fill(Color.white.opacity(0.05)).frame(height: 0.5)

        VStack(spacing: 8) {
            // Header: "THEME" label + ชื่อธีมที่เลือกอยู่ (สีธีมนั้น)
            HStack {
                Text("THEME")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                    .tracking(1.5)
                Spacer()
                Text(appThemes[selectedTheme].name)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.accent)
                    .tracking(1)
                    .animation(.easeInOut(duration: 0.2), value: selectedTheme)
            }
            .padding(.horizontal, 12)

            // Grid 5x2
            let cols = 5
            VStack(spacing: 5) {
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: 5) {
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
        .padding(.vertical, 10)
    }
}
```

---

### 4. แทนที่ฟังก์ชัน `themePreset` ทั้งหมดด้วย:

```swift
private func themePreset(_ t: AppTheme, index: Int) -> some View {
    let isActive = index == selectedTheme

    return Button {
        withAnimation(.easeInOut(duration: 0.2)) { selectedTheme = index }
    } label: {
        VStack(spacing: 4) {
            ZStack {
                // พื้นหลัง
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(isActive ? 0.08 : 0.04))
                    .frame(width: 36, height: 36)

                // วงกลมสี
                Circle()
                    .fill(t.accent)
                    .frame(width: isActive ? 18 : 15, height: isActive ? 18 : 15)
                    .shadow(color: t.accent.opacity(isActive ? 0.7 : 0.3),
                            radius: isActive ? 6 : 3)

                // dot indicator มุมขวาล่าง (แสดงเฉพาะตอน active)
                if isActive {
                    Circle()
                        .fill(t.accent)
                        .frame(width: 4, height: 4)
                        .offset(x: 12, y: 12)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            // ring เรืองแสงตอน active
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isActive ? t.accent : Color.clear, lineWidth: 1.5)
                    .shadow(color: isActive ? t.accent.opacity(0.5) : .clear, radius: 4)
            )
            .scaleEffect(isActive ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isActive)

            // ชื่อธีม
            Text(t.name)
                .font(.system(size: 6, weight: .semibold, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(isActive ? .white.opacity(0.8) : .white.opacity(0.2))
                .animation(.easeInOut(duration: 0.2), value: isActive)
        }
    }
    .buttonStyle(.plain)
}
```

---

## สรุปสิ่งที่เปลี่ยน

| จุด | เดิม | ใหม่ |
|-----|------|------|
| icon | emoji 🟠🟢🔵 | ลบออก |
| สัญลักษณ์ธีม | emoji | วงกลมสีพร้อม glow |
| selected state | กรอบขาว | ring เรืองแสงสีธีม + dot มุมขวาล่าง + scale ขึ้น |
| header right | "9 / 10" | ชื่อธีมที่เลือกเป็นสีธีมนั้น เช่น "LIME" |
| animation | easeInOut | easeInOut + scale effect |

## ⚙️ ข้อมูลเพิ่มเติม
- macOS Deployment Target: macOS 14+
- ใช้ SwiftUI animation `.easeInOut`
- ไม่ต้องแก้ไฟล์อื่นนอกจาก `MenuBarView.swift`
