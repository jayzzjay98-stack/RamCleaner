# 🖱️ RamCleaner — Fix Theme Drag Smooth

## ปัญหา
การลากเมาส์เลื่อน theme picker ยังไม่ smooth
เพราะ `.animation(.interactiveSpring(), value: scrollOffset)` ทำให้มี lag ระหว่างลาก

---

## แก้ไขใน `MenuBarView.swift`

### แทนที่ state variables เดิมทั้ง 2 ตัว

หา:
```swift
@State private var scrollOffset: CGFloat = 0
@State private var dragStartOffset: CGFloat = 0
```

แทนที่ด้วย:
```swift
@State private var scrollOffset: CGFloat = 0
@State private var dragStartOffset: CGFloat = 0
@State private var isDragging: Bool = false
```

---

### แทนที่ GeometryReader block ทั้งหมดใน `themeSection`

หา block ที่เริ่มด้วย `GeometryReader { geo in` จนถึง `.frame(height: 52)` แล้วแทนที่ทั้งหมดด้วย:

```swift
GeometryReader { geo in
    let itemWidth: CGFloat = 46
    let totalWidth = itemWidth * CGFloat(appThemes.count) + 24
    let maxOffset = max(0, totalWidth - geo.size.width)

    HStack(spacing: 5) {
        ForEach(Array(appThemes.enumerated()), id: \.offset) { i, t in
            themePreset(t, index: i)
        }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 2)
    .offset(x: -scrollOffset)
    // ใช้ animation เฉพาะตอน momentum (หลังปล่อยเมาส์) ไม่ใช้ตอนลากจริง
    .animation(isDragging ? nil : .easeOut(duration: 0.25), value: scrollOffset)
    .gesture(
        DragGesture(minimumDistance: 2, coordinateSpace: .local)
            .onChanged { value in
                isDragging = true
                // direct 1:1 tracking — ไม่มี spring lag ระหว่างลาก
                let newOffset = dragStartOffset - value.translation.width
                scrollOffset = min(max(newOffset, 0), maxOffset)
            }
            .onEnded { value in
                isDragging = false
                dragStartOffset = scrollOffset
                // momentum หลังปล่อย
                let velocity = value.predictedEndTranslation.width - value.translation.width
                let projected = scrollOffset - velocity * 0.2
                scrollOffset = min(max(projected, 0), maxOffset)
                dragStartOffset = scrollOffset
            }
    )
}
.frame(height: 52)
.clipped()
```

---

## สิ่งที่เปลี่ยน

| จุด | เดิม | ใหม่ |
|-----|------|------|
| ระหว่างลาก | มี spring animation (lag) | ไม่มี animation — 1:1 กับนิ้ว |
| หลังปล่อย | animation ผิดทิศ | momentum ถูกทิศ smooth |
| `isDragging` flag | ไม่มี | เพิ่มเพื่อ switch on/off animation |

---

## ⚙️ หมายเหตุ
- แก้แค่ **1 ไฟล์** คือ `MenuBarView.swift`
- ไม่ต้องแก้ไฟล์อื่น
