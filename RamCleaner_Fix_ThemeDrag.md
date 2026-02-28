# 🖱️ RamCleaner — Theme Picker Mouse Drag Scroll

## ปัญหา
`ScrollView` ปกติบน macOS scroll ได้เฉพาะ trackpad เท่านั้น
ต้องการให้ **คลิกค้างแล้วลากเมาส์ซ้าย/ขวา** เพื่อเลื่อนดู theme ได้

---

## แก้ไขใน `MenuBarView.swift`

### ขั้นตอนที่ 1 — เพิ่ม state variables ใน `MenuBarView` struct

เพิ่มบรรทัดเหล่านี้ต่อจาก `@State` ตัวอื่นๆ ที่มีอยู่แล้ว:

```swift
@State private var scrollOffset: CGFloat = 0
@State private var dragStartOffset: CGFloat = 0
```

---

### ขั้นตอนที่ 2 — แทนที่ ScrollView ใน `themeSection`

หา block นี้:
```swift
ScrollView(.horizontal, showsIndicators: false) {
    HStack(spacing: 5) {
        ForEach(Array(appThemes.enumerated()), id: \.offset) { i, t in
            themePreset(t, index: i)
        }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 2)
}
```

แทนที่ด้วย:
```swift
GeometryReader { geo in
    let itemWidth: CGFloat = 46   // width ของแต่ละ swatch (36) + spacing (5) + padding
    let totalWidth = itemWidth * CGFloat(appThemes.count) + 24  // 24 = padding horizontal
    let maxOffset = max(0, totalWidth - geo.size.width)

    HStack(spacing: 5) {
        ForEach(Array(appThemes.enumerated()), id: \.offset) { i, t in
            themePreset(t, index: i)
        }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 2)
    .offset(x: -scrollOffset)
    .gesture(
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let newOffset = dragStartOffset - value.translation.width
                scrollOffset = min(max(newOffset, 0), maxOffset)
            }
            .onEnded { value in
                dragStartOffset = scrollOffset
                // momentum: เลื่อนต่อเล็กน้อยหลังปล่อยเมาส์
                let velocity = -value.predictedEndTranslation.width - (-value.translation.width)
                let projected = scrollOffset + velocity * 0.15
                withAnimation(.easeOut(duration: 0.3)) {
                    scrollOffset = min(max(projected, 0), maxOffset)
                }
                dragStartOffset = scrollOffset
            }
    )
    .animation(.interactiveSpring(), value: scrollOffset)
}
.frame(height: 52)  // ความสูงพอดีกับ swatch (36) + ชื่อ (8) + spacing (4) + padding (4)
.clipped()
```

---

## ผลลัพธ์

| interaction | ผล |
|------------|-----|
| คลิกค้างแล้วลากซ้าย | เลื่อนดู theme ถัดไป |
| คลิกค้างแล้วลากขวา | เลื่อนกลับ |
| ปล่อยเมาส์ | มี momentum เลื่อนต่อเล็กน้อย |
| คลิกเบาๆ (ไม่ลาก) | เลือก theme ปกติ |

---

## ⚙️ หมายเหตุ
- แก้แค่ **1 ไฟล์** คือ `MenuBarView.swift`
- `minimumDistance: 2` ทำให้ gesture แยกออกจาก click ปกติได้
- ไม่ต้องแก้ `themePreset` function
- ไม่ต้องแก้ไฟล์อื่น
