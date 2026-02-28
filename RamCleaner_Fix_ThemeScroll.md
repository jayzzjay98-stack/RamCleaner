# 🎨 RamCleaner — Theme Picker Horizontal Scroll

## เป้าหมาย
เปลี่ยน Theme Picker จาก grid 5x2 (2 แถว) เป็น **แถวเดียว scroll แนวนอนได้**
โชว์ 5 สีพร้อมกัน ที่เหลืออีก 5 สีลากเมาส์เลื่อนดูได้
ทำให้หน้าต่างโปรแกรม **สั้นลง** เพราะลดจาก 2 แถวเหลือ 1 แถว

---

## แก้ไขใน `MenuBarView.swift`

### แทนที่ส่วน grid ใน `themeSection`

หา block นี้ใน `themeSection`:
```swift
let cols = 5
VStack(spacing: 3) {
    ForEach(0..<2, id: \.self) { row in
        HStack(spacing: 4) {
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
```

แทนที่ด้วย:
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

---

## ผลลัพธ์

| จุด | เดิม | ใหม่ |
|-----|------|------|
| layout | grid 5x2 (2 แถว) | แถวเดียว scroll แนวนอน |
| การดู theme | เห็นทั้งหมด 10 พร้อมกัน | เห็น 5 แล้ว scroll ดูที่เหลือ |
| ความสูงหน้าต่าง | สูงกว่า | **สั้นลง 1 แถว** |
| interaction | คลิก | คลิก + ลากเมาส์เลื่อนซ้าย/ขวา |

---

## ⚙️ หมายเหตุ
- macOS `ScrollView` รองรับ trackpad swipe และ mouse drag ได้เลย ไม่ต้องเพิ่ม gesture
- ไม่ต้องแก้ `themePreset` function — ใช้เดิมได้เลย
- ไม่ต้องแก้ไฟล์อื่น
