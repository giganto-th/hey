# Hey! — Hei Hei UX redesign

ดู [สเปก UX และแอนิเมชัน](UX-MOTION-SPEC.md) และเปิด `preview.html` ในเบราว์เซอร์เพื่อลองแบบจำลอง ไม่มีการติดตั้งหรือเชื่อมบัญชี

## สิ่งที่ลองได้

1. กด “เล่นเพลงจำลอง” เพื่อดู 8 key poses ที่ใช้สื่อบุคลิกของ Hei Hei
2. พิมพ์ในโน้ต: สลับไปจิกคีย์บอร์ด หยุด 2.5 วินาทีแล้วกลับไปเต้น
3. เริ่มโฟกัส: หยุดเต้น พิมพ์ระหว่างโฟกัสจะจิกช้าลง
4. คลิกตัวละคร: เปิดคำสั่งด่วน; Esc ปิดและคืน focus
5. เปิด Hub: เปลี่ยนหมวดวันนี้ เพลง ไฟล์และโน้ต โฟกัสและเตือน Hei Hei และตั้งค่า
6. ปรับการเคลื่อนไหวหรือปิด typing/dance: ผลเปลี่ยนในต้นแบบทันที

ข้อมูลใน Hub และเวลาตัวจับเวลาเป็นตัวอย่าง จังหวะเพลงจำลอง 108 BPM ไม่มีเสียง ไม่ใช่ beat detection จริง รับ input เฉพาะช่องโน้ต ไม่รับ global keyboard ไม่เก็บข้อความลง storage

แบบจำลองใช้ภาพ key poses ข้ามช่องเพื่อให้เห็นแนวคิด ไม่ใช่แอนิเมชัน atlas สำเร็จ: ยังต้องวาด in-between, จัด anchor, แยก props, rig และทดสอบบน macOS

## ไฟล์

- `UX-MOTION-SPEC.md`: รายละเอียด UX, พฤติกรรม, priority, transition, asset contract และเกณฑ์ตรวจ
- `heihei-motion-concept-v1.png`: ภาพต้นฉบับจาก built-in imagegen
- `heihei-motion-preview-v1.webp`: สำเนาเข้ารหัสสำหรับแสดงผล ขนาดและ alpha เดิม
- `IMAGE-PROMPT.md`: prompt และ provenance ภาพ
- `preview.fragment.html`: source ของต้นแบบ
- `preview.html`: ต้นแบบ standalone ที่ฝังภาพแล้ว
- `build-preview.mjs`: ประกอบต้นแบบใหม่โดยไม่ใช้ package ภายนอก

```sh
node docs/redesign/build-preview.mjs
open docs/redesign/preview.html
```

ต้นแบบในโฟลเดอร์นี้ยังเปิดดูแยกจากแอปได้ และมีการนำแบบเข้าสู่แอป Swift แล้วตาม [IMPLEMENTATION.md](IMPLEMENTATION.md) รวมถึง runtime, save migration และ packaging

## การตรวจ

- ตรวจ JavaScript syntax และขนาด inline preview ต่ำกว่า 1 MB
- เปิดตรวจ desktop, Hub และ motion settings ผ่านเบราว์เซอร์
- ทดลองเพลง/typing, การกลับไปเต้น และการเลือกหมวด Hub
- ทดลองโฟกัสขณะเพลงเล่น, quick menu, Esc และลดการเคลื่อนไหว
- ตรวจ desktop และ motion settings ที่ 320 px: document width 320 px ไม่เกิด horizontal overflow
- ตรวจ console ของต้นแบบ standalone: ไม่พบ error/warning
- ตรวจแยก key pose ที่เป็น concept ออกจาก requirement ของ production
