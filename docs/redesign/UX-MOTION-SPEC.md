# Hey! — UX/UI และระบบแอนิเมชัน Hei Hei v2

สถานะ: แบบออกแบบและต้นแบบสำหรับตรวจประสบการณ์ ไม่ใช่แอนิเมชันที่เชื่อมแอปจริงแล้ว
วันที่: 3 พฤศจิกายน 2026
ขอบเขต: ออกแบบ UX/UI ใหม่ทั้งหมด และกำหนดระบบพฤติกรรม 2D อย่างละเอียดตามคำขอผู้ใช้ โดยใช้ Hei Hei จาก Moana เป็นตัวละครหลัก แทนทิศทาง Tok เดิม

## 1. หลักของประสบการณ์

สัตว์เลี้ยงเป็นเพื่อนร่วมโต๊ะที่รับรู้กิจกรรม แต่ไม่ขัดงาน ตัวละครมีบุคลิกซื่อ งง ช่างสงสัย และตลกจากจังหวะร่างกาย ผู้ใช้สั่งงานได้แน่นอนแม้ตัวละครจะดูซุ่มซ่าม ห้ามใช้ความซุ่มซ่ามเป็นเหตุให้ไฟล์หาย คลิกผิด หรืองานเสร็จช้า

- อยู่บริเวณที่ผู้ใช้เลือก ไม่วิ่งเข้าหา caret หรือคลุมข้อความที่กำลังพิมพ์
- แสดงเรื่องเดียวเป็นหลักในแต่ละขณะ มีท่าทางรองได้เมื่อไม่ทำให้อ่านพฤติกรรมหลักผิด
- เครื่องมือเร็วอยู่ใกล้ตัว; งานที่มีรายการและรายละเอียดอยู่ใน Hub
- สถานะสำคัญมีข้อความและปุ่มเสมอ ไม่พึ่งสีหรือท่าสัตว์เพียงอย่างเดียว
- ไม่มีเสียงไก่อัตโนมัติขณะพิมพ์หรือทำงาน ค่าเริ่มต้นเสียงตัวละครปิด

## 2. Art direction: ใกล้ Hei Hei ฉบับแอนิเมชัน

อ้างอิงภาพยนตร์ Moana ฉบับแอนิเมชัน ไม่ใช้ลักษณะไก่สมจริงฉบับ live action และไม่เปลี่ยนเป็นนกกลมคอสั้น

| ลักษณะ | ข้อกำหนด |
|---|---|
| Silhouette | ลำตัวเล็ก คอยาวและงอได้ ขาเรียว หางเป็นพวงโค้ง อ่านเป็น Hei Hei แม้เห็นเป็นเงา |
| ดวงตา | ตาขาวโปนสองข้าง รูม่านตาเล็ก เคลื่อนเป็นอิสระ มีทั้งมองคนละทางและจ้องผิดจุด ไม่บังคับตาเหล่เข้ากลางตลอดเวลา |
| หงอน/เหนียง | แดงอมส้ม ทรงไม่สมมาตร มีแรงตามหลังการเคลื่อนหัว |
| สี | คอเหลืองทอง ลำตัวน้ำตาล ปีกน้ำตาลเข้ม หางเขียวอมฟ้า ปากและขาเหลืองส้ม |
| สัดส่วน | ศีรษะและคอยาวรวมราว 55–65% ของความสูงตัวตรง เป็นเป้าออกแบบ ต้องเทียบ model sheet |
| ใบหน้า | งง ชะงัก มองผิดทิศ ก่อนรับรู้; ลิ้นใช้เฉพาะบางท่าปากอ้า ไม่ติดลิ้นห้อยทุกท่า |
| การเคลื่อน | หัวเริ่มก่อน คอตาม ตัวตามอีกนิด หาง/หงอนตามหลัง; ปีกกระพือสั้นไม่สมมาตร |
| การเติบโต | ตัวเต็มวัยเป็น reference หลัก ลูกไก่/เด็กเป็นการตีความสำหรับเกม ต้องคงดวงตา โทนสี และบุคลิกเดียวกัน |
| สิ่งที่ต้องรักษา | ตัวละครยังอ่านง่ายที่ความสูง 96, 128, 160 และ 192 pt; ไม่เพิ่มเสื้อผ้าหรือหูฟังถาวร |

ภาพ `heihei-motion-concept-v1.png` เป็น concept 8 key poses: idle, dance ซ้าย/ขวา/downbeat, peck prepare/contact/recover, sleepy ภาพแต่ละช่องยังไม่ได้ปรับจุด anchor หรือสร้าง in-between จึงห้ามใช้เป็น atlas ส่งจริงโดยตรง

แหล่งอ้างอิงบุคลิก: [Disney D23 — Alan Tudyk / Heihei](https://d23.com/whos-that-good-luck-charm-ing-voice-in-moana/), [Disney — recording for Hei Hei](https://video.disney.com/watch/moanamondays-alan-tudyk-recording-for-hei-hei-53ca6b1d6985254f4b4c54ef)

## 3. Information architecture และหน้าจอ

### 3.1 Companion บน desktop

- ตัวละครสูงเริ่มต้น 128 pt ปรับได้ 80–192 pt; คีย์บอร์ดจิ๋วอยู่ในพื้นที่ของตัวละคร ไม่พาดพื้นที่งาน
- hover 250 ms: แสดงปุ่มคำสั่งเล็กเพียงปุ่มเดียว พร้อมชื่อ ไม่เปิดเมนูเอง; keyboard เข้าใช้ผ่านไอคอนเมนูบาร์ได้
- คลิกหนึ่งครั้ง: สนใจผู้ใช้ 600–900 ms และแสดงแถบคำสั่งสั้น ถ้าลากเกิน 6 pt ให้ถือเป็นอุ้มแทน
- ลูบ: เคลื่อนสลับทิศบนลำตัวตาม stroke detector เดิม มี cooldown รางวัล แยกจากการเปิดเมนู
- คลิกขวา: quick menu 4 คำสั่งหลัก เพลง / ฝากไฟล์ / โฟกัส / Hub; อาหารอยู่ในการ์ดดูแลที่เรียกได้อีกขั้น
- ปุ่มมี label เสมอ มี fallback เป็นเมนูแนวตั้งเมื่อพื้นที่จอไม่พอ; Esc ปิด; คืน focus ให้หน้าต่างงานเดิม
- อุ้ม: ล็อก anchor ที่จุดจับ หน้าต่างรับเมาส์ต่อเนื่องจนปล่อย; ปล่อยแล้วตก/ลงพื้นตามระบบเดิม
- ห้ามเปลี่ยนตำแหน่งเองขณะเมนูเปิด กำลังพิมพ์ รับไฟล์ หรืออัดภาพ/วิดีโอ

### 3.2 Context capsule

การ์ดลอยหนึ่งใบเหนือ/ข้างตัว ไม่เกิน 280 pt กว้าง เลือกด้านที่มีพื้นที่และ clamp เข้า visible frame ทุกจอ

| บริบท | ข้อมูลและคำสั่ง |
|---|---|
| เพลง | ชื่อเพลง 1–2 บรรทัด, แหล่งเสียง, ก่อนหน้า/เล่น/ถัดไป, เสียง; ขยายเมื่อผู้ใช้เรียกเท่านั้น |
| โฟกัส | เวลาคงเหลือ, หยุดชั่วคราว/จบรอบ; ไม่กระตุกตัวเลขทุกเฟรม |
| เตือน | ข้อความ, รับทราบ, เลื่อน; ไม่หายเพราะสัตว์เดินหรือหลับ |
| รับไฟล์ | ฝากเก็บ / พักไว้ลากต่อ; ข้อความยืนยันจำนวนเมื่อเสร็จจริง |
| ดูแล | ความอิ่ม อารมณ์ พลังงาน พร้อมอาหารที่ให้ได้; ข้อผิดพลาดบอกวิธีแก้ |

ข้อความบุคลิกธรรมดาหาย 3–4 วินาที สูงสุดหนึ่งครั้งต่อ 10 นาที; toast ยืนยันคำสั่งไม่ติดข้อจำกัดนี้และไม่แย่ง focus

### 3.3 Hub ใหม่: 6 หมวดแทน sidebar 14 รายการ

| หมวด | เนื้อหา | Primary action |
|---|---|---|
| วันนี้ | สถานะตัวละคร, เตือนถัดไป, โฟกัสที่กำลังทำ, ไฟล์ล่าสุด | เริ่มโฟกัส / ดูแล ตามบริบท |
| เพลง | เล่นอยู่, คิว, เพลย์ลิสต์, เพิ่มลิงก์/ไฟล์ | เพิ่มเพลง |
| ไฟล์และโน้ต | segmented ฝากเก็บ / ถาดพัก / โน้ต, ค้นหาและจัดการ | เพิ่มรายการ |
| โฟกัสและเตือน | timer, เตือนทั้งหมด, ประวัติรอบ | ตั้งเตือน |
| Hei Hei | ดูแล, เติบโต, ภารกิจ, ของสะสม, มินิเกม | ให้อาหาร |
| การตั้งค่า | การเคลื่อนไหว, พฤติกรรม, สิทธิ์, พลังงาน, คีย์ลัด, ถ่าย/อัดและแกลเลอรี | ตามหน้ารอง |

ถ่าย/อัดยังเรียกผ่าน quick menu และคีย์ลัดได้ ไม่ต้องเปิดหน้าตั้งค่าเพื่อเริ่มบันทึก แกลเลอรีมีทางเข้าจากผลลัพธ์หลังบันทึกด้วย

หน้าต่าง Hub เริ่ม 960×680 pt ขั้นต่ำ 760×540 pt sidebar 184–204 pt; ใช้พื้นที่เนื้อหาและแถบรายละเอียดเฉพาะเมื่อเลือกของจริง ไม่มี dashboard ตัวเลขที่ไม่ช่วยตัดสินใจ

### 3.4 Visual system

- ผิวหน้าต่าง macOS เป็นหลัก; Liquid Glass ใช้กับ quick menu/capsule/toolbar ไม่ซ้อนกระจกทุกชั้น
- ใช้พื้น warm neutral ใน light mode และ charcoal ใน dark mode สีเนื้อหาต้องปรับตาม appearance
- Accent teal สำหรับ selected/primary, เหลืองทองใช้กับพลังงาน/อาหาร, แดงใช้เหตุจำเป็น; ตัวละครยังเป็นจุดสีเด่นที่สุด
- SF Pro สำหรับละตินและ system Thai fallback; title 22/28, section 15/20, body 13/18, caption 11/15 pt; Dynamic Type/Accessibility ขยายได้
- spacing 4/8/12/16/24/32 pt; radius card 16, popover 20, control 8–10 pt; ข้อความอ่านได้โดยไม่พึ่ง transparency
- สถานะ empty/loading/error/offline/permission denied ต้องออกแบบทุกหน้าที่เกี่ยวข้อง ไม่ใช้ spinner ไม่มีข้อความ

## 4. Motion architecture

แทนการโยกรูปทั้งตัวจากหลาย SKAction พร้อมกัน แยก resolver ออกจาก renderer และแยก channel:

1. **Lifecycle:** visible / hidden / dormant คุมการ render และ input
2. **Locomotion:** standing / walking / carried / falling / landing / perching คุมตำแหน่งจริง
3. **Activity:** idle / typing / dancing / focusing / receiving / eating คุมท่าหลัก
4. **Expression:** curious / pleased / startled / tired / hot / worried คุมตา ปาก หงอน
5. **Secondary motion:** หาง เหนียง หายใจ เฉพาะเมื่อ budget และท่าหลักอนุญาต
6. **Props:** คีย์บอร์ด อาหาร โน้ต กล่องไฟล์ แยก node และ hit region จากสัตว์

Root → physicsRoot → facingRoot → bodyRig (body, neck, head, eyes, beak, comb, wattles, wings, tail, legs) + propRoot + independent UIAnchor

UIAnchor ไม่สืบทอดการหมุน/สั่นของตัวละคร ตัวหนังสือจึงอยู่นิ่ง เมนูไม่โยกตามไก่ การกลับซ้าย/ขวา flip เฉพาะตัวละคร ไม่ flip ตัวหนังสือ/โลโก้บน prop

Hybrid rendering: ท่า idle/walk/dance ใช้ rig ที่วาดชิ้นส่วนซ้อนกัน ส่วน neck bend ของ peck, squash และ expression บางแบบใช้ authored key frames/mesh deformation ต้องวาดส่วนคอที่ซ่อนอยู่เผื่อหมุน ไม่ตัดภาพแบนแล้วเผยช่องว่าง

## 5. Arbitration และการเปลี่ยนท่า

ลำดับ override จากสูงลงต่ำ:

| ระดับ | เหตุการณ์ | การตัดสินใจ |
|---|---|---|
| 100 | จอล็อก/หลับ/ผู้ใช้ซ่อน | จบ render, หยุด prop/เสียง, ระบบเตือนยังคง scheduler |
| 90 | อุ้ม/ตก/ลงพื้น | ยกเลิก activity; ใช้ท่าร่างกายตามฟิสิกส์ทันที |
| 80 | ลากไฟล์ผ่านตัว/เปิดเมนู | ยืนรับคำสั่ง, ปิด prop ที่กีดขวาง hit target |
| 70 | อาหาร/คลิก/ลูบโดยผู้ใช้ | เล่น one-shot; ไม่เก็บคิวซ้ำเกินหนึ่งรายการ |
| 60 | พิมพ์ | peck keyboard; ถ้ามีเพลงให้หางโยกเบา ๆ แต่เท้ายังตรึง |
| 50 | โฟกัส | ท่านิ่ง ลดความแรง typing เหลือ 25%; ไม่เต้นหรือเดิน |
| 40 | เพลงกำลังเล่น | dance; ขณะ buffering/paused หยุดรอบเต้นอย่างนุ่มนวล |
| 20 | idle/เดิน/งีบ | เลือกตามสถานะและ cooldown |

ภาวะร้อนรุนแรง/แบตวิกฤตกำหนด motion ceiling เหนือทุก activity ที่เหลือ: หยุดท่าแรงและ props ที่ไม่จำเป็น ใช้ worried idle มีข้อความครั้งเดียว การลาก/คำสั่งผู้ใช้ยังต้องทำงาน

- การ interrupt ที่มีผลกับ input ยกเลิกได้ภายในหนึ่งเฟรม renderer
- transition ปกติ 120–220 ms; หยุดเพลงใช้ settle 250–350 ms; landing 180–260 ms
- activity คำนวณใหม่จากสัญญาณปัจจุบัน ไม่ resume clip เก่า: เมื่อปล่อยมือแล้วหยุดพิมพ์ไปแล้ว ต้องไม่กลับไปจิก
- เปลี่ยนช้าเป็นเร็วต้องคง phase ของท่า ไม่เริ่มต้นทั้งคลิปใหม่ทุก sample
- รับ event ซ้ำใช้ semantic key dedupe; queue transient events สูงสุด 3 อายุไม่เกิน 2 วินาที และทิ้งเมื่อบริบทเปลี่ยน
- ห้าม happy/eat/low-battery tint หลาย action เขียน transform หรือสีของ node เดียวกันพร้อมกัน

## 6. Typing: ไก่จิกคีย์บอร์ด

แหล่งข้อมูล: จำนวน key-down จาก counter ที่ระบบเดิมใช้ ไม่อ่านตัวอักษร ไม่ติดตาม caret ไม่สร้าง keyboard event จริง

| ช่วง | Trigger / เวลาเป้าหมาย | การเคลื่อน |
|---|---|---|
| Notice | พบ counter เพิ่ม; sampling ขณะ idle 0.5–1 s | ตาเหลือบลง 100–150 ms หัวเอียงเล็กน้อย |
| Setup | typing ต่อเนื่อง 250 ms | keyboard จิ๋ว slide เข้า 150–200 ms ข้างหน้าเท้าในพื้นที่ตัวละคร |
| Prepare | เริ่มหนึ่ง cycle | คอโก่ง หัวหดเล็กน้อย 80–110 ms |
| Strike | กลาง cycle | ปากจิกลงที่ปุ่ม 50–70 ms; ปุ่มยุบ 1–2 pt |
| Contact | 30–50 ms | เท้าไม่เลื่อน ลำตัวถ่วงไปข้างหน้าไม่เกิน 3 pt |
| Recover | 100–140 ms | หัวเด้งกลับ เหนียงตามหลัง 40–70 ms |
| Hold | หยุดพิมพ์ไม่เกิน 2.5 s | ค้างอยู่กับ keyboard, ไม่กาง/เก็บ prop ระหว่างคำ |
| Exit | ไม่มี key ใหม่เกิน 2.5 s | จบ cycle ปัจจุบัน เงยหน้างง 180 ms เก็บ keyboard 160 ms |

ความถี่จิก: <1 key/s ใช้ 1–1.4 cycle/s, 1–4 key/s ใช้ 1.5–2.2 cycle/s, >4 key/s ใช้ 2.3–3 cycle/s เป็นเพดาน ไม่จิกหนึ่งครั้งต่อทุกปุ่มและไม่เก็บ event ไว้เล่นย้อนหลัง

สลับจุดจิก 3 ตำแหน่ง ใช้ weighted random; 85% จิกปุ่ม, 10% ชะงักมองผิดจุด, 5% จิกพลาดข้างปุ่มโดยไม่มีเสียง ภายใน 20 วินาทีแรกเล่น straightforward เพื่อให้ผู้ใช้เข้าใจพฤติกรรมก่อน

Typing + music: typing ชนะ หาง/ปีกขยับตาม pulse ได้เพียง 10–15% แล้วคืน dance บนจังหวะถัดไปหลัง hold สิ้นสุด Typing + focus: จิกเบา ไม่มีมุก ไม่มี bubble Typing + menu/drop: เก็บ prop ทันที ไม่บังปุ่มรับคำสั่ง

Acceptance: เป้าหมายเริ่มรับรู้ <=1.2 s เมื่อ idle และ <=300 ms ขณะ sampling เร็ว; หยุดแล้วไม่กลับมาเล่น key เก่า; ไม่อ่านหรือเก็บเนื้อหาพิมพ์; เปิด typing setting ปิดต้องจบ prop/ท่าค้างด้วย

## 7. Music: เต้นแบบ Hei Hei

### 7.1 ความสามารถของแหล่งเพลงต้องชัด

| แหล่ง | ทำได้ | UI ที่แสดง |
|---|---|---|
| เพลงในเครื่องผ่าน engine ของแอป | วิเคราะห์ PCM → onset/energy → beat estimate เมื่อเพิ่ม audio pipeline | “ตามจังหวะเสียง” เฉพาะเมื่อ confidence ผ่าน |
| YouTube IFrame | รับ playing/paused/buffering/position ไม่ได้มี PCM/beat ใน API นี้ | “เต้นขณะเล่นเพลง” + จังหวะอัตโนมัติหรือ Tap tempo |
| Now Playing ของแอปอื่น | ชื่อและสถานะเท่าที่อ่านได้; ไม่ถือว่าได้ยินเสียง | “รับรู้สถานะการเล่น” ไม่อ้างว่าตรวจ beat ได้ |
| Tap tempo | ผู้ใช้เคาะ 4–8 ครั้ง; median interval ตัด outlier | “จังหวะที่ตั้งเอง · … BPM” |
| แหล่งหาย/ไม่รองรับ | idle อย่างนุ่มนวล | ปุ่มลองใหม่ และข้อความสถานะที่ตรงจริง |

ต้นแบบใช้ “จังหวะจำลอง 108 BPM” ไม่มีการเล่นเสียงหรือฟังเพลงจริง

อ้างอิง: [Apple AVAudioNode audio tap](https://developer.apple.com/documentation/avfaudio/avaudionode/installtap(onbus:buffersize:format:block:)), [YouTube IFrame API](https://developers.google.com/youtube/iframe_api_reference). PCM tap เป็นทางเข้าวิเคราะห์เสียง ไม่ใช่ beat detector สำเร็จรูป; ต้องพัฒนาและวัดความแม่นยำเอง

### 7.2 จังหวะและ choreography

| สถานการณ์ | การเคลื่อน |
|---|---|
| เริ่มเล่น | ชะงักหูผึ่ง/ตาเบน 200 ms แล้ว pickup เข้า groove ภายใน 1 s |
| เพลงช้า <90 BPM | knee bob ทุก beat, head sway ครึ่งจังหวะ, wing flick ทุก 4 beats |
| 90–130 BPM | step ซ้าย/ขวาทุก beat, คอยืด/หด, head tilt เหลื่อมหนึ่ง eighth note |
| >130 BPM | dance half-time 65–90 movement BPM ไม่เร่งกระโดดไม่จำกัด |
| accent/downbeat | squat สั้น 2–4 pt + ปีกกาง; ไม่ flash หรือเขย่าหน้าจอ |
| ท่าพิเศษ | head wobble / wing shuffle / tiny turn ทุก 8–16 bars, cooldown 20 s |
| ตั้งใจให้ตลก | ตัวเข้า beat แต่หัวเหลื่อมเพียง 60–100 ms เป็นบางรอบ; ไม่ jitter ทุกเฟรม |
| pause | จบ step ใกล้สุดเท้าลงพื้น เก็บปีกกลับ 250–350 ms |
| buffering | หยุดเต้น คอเอียงรอ; ไม่ยังเต้นแรงเสมือนเสียงกำลังเล่น |
| seek/เปลี่ยนเพลง | reset confidence/phase, settle แล้ว pickup ไม่ต่อจังหวะเพลงเก่า |

Beat tracker ในการพัฒนาจริง: วิเคราะห์ mono downsample 22.05 kHz บน worker, hop 512 samples, ปรับ energy ตาม loudness; confidence 0–1; เข้า beat-sync เมื่อ >=0.65 ต่อเนื่อง 2 s ออกเมื่อ <0.4 ต่อเนื่อง 3 s, phase correction จำกัดไม่เกิน 30 ms/beat และ tempo slew ไม่เกิน 5%/s ทั้งหมดเป็นค่าเริ่มต้นที่ต้อง tune ด้วยเพลงหลายแนว ไม่ใช่ค่าที่รับรองผลแล้ว

วางเท้าหลักที่ anchor เดิม ไม่เต้นข้ามหน้าต่างหรือปุ่ม อนุญาต sway สูงสุด 6 pt/4° ในโหมดเต็ม เพลงเปิดพร้อมโฟกัสให้สงบนิ่ง ห้ามเต้นแข่งกับงาน

## 8. Behavior catalogue สำหรับสถานการณ์อื่น

| สถานการณ์ | ท่าทาง / ระยะ / เงื่อนไข |
|---|---|
| Idle | หายใจ 2–3 s/cycle, blink 4–8 s; มองคนละทางทุก 12–20 s; ไม่ blink ประสานตาทุกครั้ง |
| เมาส์เข้าใกล้ | ตามด้วยตาก่อน 100 ms คอเอียง 150 ms; ไม่หันทั้งตัวทันที; ไม่มี bubble |
| ลูบ | ตาปรือ คอย่น ปีกหลวม 0.8–1.2 s; ซ้ำขณะลูบได้แต่รางวัลติด cooldown |
| อุ้ม | ขาห้อย/ปีกแผ่ คอยืดรับแรงตาม pointer แบบ spring ที่จำกัดองศา; หยุด music/typing pose |
| ตก | หัวชะงัก ปีกพยายามทรงตัว; ยึด velocity ของฟิสิกส์ ไม่ใช้เวลา clip เป็นตำแหน่งจริง |
| ลงพื้น | squash 6–8% 80 ms → rebound 120 ms → puzzled idle; เท้าไม่จมหรือสั่น |
| เดิน | head bob สวน phase เท้า; หางตามหลัง 80–120 ms; หยุดเดินก่อนสนใจ pointer |
| เกาะหน้าต่าง | มองขอบก่อนก้าว ไม่มีการทะลุหน้าต่าง; ขอบหายต้องเข้าสู่ falling; โหมดประหยัดยกเลิกเกาะ |
| รับไฟล์ | จ้องสิ่งของ → กางปีก → รอยืนยันสำเร็จ; ตัวละครไม่กลืนไฟล์ก่อน copy เสร็จ |
| เก็บไฟล์สำเร็จ | จิกป้ายกล่องเบา ๆ หนึ่งครั้ง + toast จำนวนรายการจริง 2.5 s |
| เก็บไฟล์ล้มเหลว | หัวเอียง + toast “เก็บไม่สำเร็จ” พร้อมลองใหม่/ดูรายละเอียด; ไม่ฉลอง |
| ให้อาหาร | ก้มดม 200 ms → จิก 2–3 ครั้ง 600 ms → เงยหน้ากลืน 250 ms; อาหารลดเมื่อ domain ยอมรับแล้ว |
| เตือนครบเวลา | หัวผงกหันหาการ์ด 600 ms; toast มีปุ่มรับทราบ/เลื่อน; ไม่จิกหรือกดปุ่มแทนผู้ใช้ |
| เริ่มโฟกัส | settle เข้า quiet perch 300 ms; เฝ้างานเงียบ ๆ; เผยเวลาผ่าน capsule ที่ผู้ใช้เรียก |
| จบรอบ | wing pop 700 ms + แจ้งเตือนหนึ่งครั้ง; ไม่เฉลิมฉลองต่อเนื่อง |
| ไม่ใช้เครื่อง 3 นาที | หาว → คอย่น → งีบ; เมื่อเพลงยังเล่นใช้ sleepy sway เบามาก ไม่หลับแล้วเต้นแรงพร้อมกัน |
| กลับมาใช้ | ลืมตาทีละข้าง เหลือบผิดทาง ก่อนหันมา 800 ms; ต้อนรับมี cooldown |
| แบตต่ำ/ร้อน | ลด amplitude; tired/worried expression; แจ้งครั้งเดียวตาม threshold hysteresis |
| อัดหน้าจอ | auto calm และซ่อน UI overlay ตาม capture filter; indicator การอัดยังเข้าถึงได้จากเมนูบาร์ |
| Fullscreen/ล็อก | ซ่อนตาม setting หยุด renderer; กลับมา clamp ตำแหน่ง ไม่เล่น animation ที่พลาดย้อนหลัง |
| ไข่ | ใช้ wobble/ร้าวเล็กน้อย แทน dance/peck ที่ต้องมีร่างกาย; หน้าตั้งค่าบอกว่าท่าบางอย่างปลดล็อกหลังฟัก |

## 9. Motion settings และ accessibility

- Master: เต็ม / นุ่มนวล / ลดการเคลื่อนไหว และปิดเฉพาะ typing, dance, roaming, climb, curiosity, reactions ได้
- เคารพ system Reduce Motion เป็นค่าเริ่มต้น; ผู้ใช้ override เฉพาะแอปได้อย่างชัดเจน
- Reduced: ใช้ท่านิ่งแสดงกิจกรรม เปลี่ยน expression เป็นครั้ง ๆ ไม่มี loop, hop, rotation, secondary jiggle
- โหมดนุ่มนวล: amplitude 35%, ไม่มี hop/มุกสุ่ม; ยังบอกกิจกรรมได้
- ทุกปุ่มมี VoiceOver label; quick menu มีลำดับโฟกัสแน่นอน และมีเมนูบาร์เป็นทางเข้าเสมอ
- สีไม่เป็นหลักฐานเดียวของความหิว/พลังงาน ขนาดข้อความไม่ผูกกับขนาดสัตว์
- ไม่ประกาศท่าทุกเฟรมให้ screen reader; ประกาศเฉพาะสถานะที่มีผลกับงาน/คำสั่ง

## 10. Asset contract และ animation inventory

เริ่มทำ adult ให้ผ่านก่อนขยายไปทุกวัย; ไม่คูณทุกท่าด้วย 5 วัยทันที

| ชุด | คลิปหลัก | จำนวนภาพวาดเริ่มต้นต่อคลิป |
|---|---|---|
| Foundation | idle, blink, look, walk, turn, sleep-enter, sleep, wake | 4 / 3 / 4 / 8 / 4 / 6 / 4 / 6 |
| Direct interaction | pet, grab, carried, falling, land, eat | 6 / 4 / 4 / 4 / 6 / 8 |
| Typing | setup, peck-slow, peck-fast, miss, recover, exit | 6 / 6 / 6 / 6 / 4 / 5 |
| Music | pickup, groove, step-left, step-right, downbeat, wing-shuffle, settle | 6 / 8 / 6 / 6 / 4 / 8 / 6 |
| Tools | receive, success, error, focus, focus-finish, reminder | 6 / 6 / 4 / 4 / 6 / 4 |

รวม 33 คลิป / 178 key frames ตามตาราง (บางคลิปใช้ rig ร่วมกันได้ จึงไม่ใช่จำนวนไฟล์สุดท้าย); expression layers และ props นับแยก ต้องทำ breakdown ก่อนผลิตจริง

- source 1024² RGBA ต่อ key pose สำหรับเก็บต้นฉบับ; export ใช้งาน 256²/512² ตามขนาดและ backing scale
- atlas page สูงสุด 2048² พร้อม padding 2 px และ extruded edge; โหลดตามชุดใช้งาน ไม่โหลดทุกวัยพร้อมกัน
- 2048² RGBA8 เท่ากับ 16 MiB ต่อ page ก่อนนับ mipmap/สำเนาของระบบ; budget resident atlas เริ่ม <=3 pages =48 MiB และวัดจริง
- metadata: clip id, stage, facing, frame durations, foot/head/beak/grab anchors, prop socket, interruption markers, loop points, bounds
- naming ตัวอย่าง `adult/typing/peck_slow/000.png`; manifest เป็นแหล่งจริง ห้าม hardcode รายชื่อท่าในหลายไฟล์
- ภาพ concept ต้องผ่าน cleanup ขอบ alpha, normalize anchor, model consistency และ in-between ก่อนนำเข้า atlas
- ถ้าภาพหาย ให้ fallback ภายในสายพันธุ์เดียวกันและบอก diagnostic ใน dev; ห้ามเปลี่ยนเป็นคนละตัวละครเงียบ ๆ

## 11. Performance targets ที่ต้องวัด

เป้าหมาย ไม่ใช่ผล benchmark ที่ตรวจแล้ว:

| โหมด | Renderer | พฤติกรรม |
|---|---|---|
| Full | 30 fps active / 8 idle | rig เต็ม, secondary ตามความจำเป็น |
| Balanced | 24 fps active / 6 idle | secondary ลดลง, จำกัด props |
| Saver | 15 fps active / 4 idle | no hop/particle/climb, dance เป็น head bob |
| Dormant | 0 fps | scheduler เตือนอยู่, หยุด audio analysis ที่ใช้เพื่อท่าเท่านั้น |

ไม่มี timer ต่อหนึ่งกระดูก/คลิป ใช้ clock กลาง; อนิเมชันเดินตาม elapsed time ไม่ตามจำนวน callback; audio worker ส่งเฉพาะ beat/energy สรุป 10–20 Hz ไม่ส่ง PCM มาที่ MainActor; ไม่สร้าง subprocess เพื่อทุก beat

วัดเพิ่ม CPU/GPU/RAM/wakeups ใน idle, typing 10 นาที, music 10 นาที, typing+music, battery saver และ hide; ตั้งเป้า idle CPU <1% / active <4% และตรวจผลบนเครื่องอย่างน้อยสองรุ่นก่อนสรุป

## 12. Mapping สู่โค้ดเดิม

| ปัจจุบัน | การเปลี่ยนที่เสนอ |
|---|---|
| `BehaviorFSM.swift` | คง locomotion เดิม แล้วเพิ่ม ActivityResolver ที่เลือก intent ตาม priority และ lifecycle |
| `Activity.swift`, `ActivityMonitor.swift` | ส่ง `TypingSignal(rate, lastKeyAt)` แยกจาก ambient; ตอนนี้ typing อาจถูก battery/hot mood กลบ |
| `MusicPlayer.swift` | ส่งสถานะ playing/buffering/paused/ended และ source capability; เพิ่ม beat engine เฉพาะ local pipeline |
| `NowPlayingReader.swift` | เป็น status source ทดลอง ไม่ส่งค่า BPM ที่เดาให้ดูเหมือนอ่านได้จริง |
| `PetScene.swift` | แยก PetRig, AnimationPlayer, PropController, SurfaceController, ActivityResolver แทน SKAction หลายกลุ่มแก้ node เดียว |
| `SpriteLibrary.swift` | เพิ่ม manifest/atlas/anchors และ explicit missing asset diagnostic |
| `HubView.swift` | แยก feature views และ navigation ใหม่; motion preview ใช้ rig เดียวกับ desktop |
| `Game.swift` | หยุด migrate `heihei` เป็น `tok` ในงาน implementation ใหม่ และทำ migration แบบระบุ version สำหรับเซฟ Tok ที่มีอยู่ |
| `make-app.sh` | แพ็ก heihei atlas ที่ใช้งานจริง; ตรวจ manifest หลังแพ็ก ป้องกัน exclude ภาพตัวหลัก |

เอกสารเดิม `MASCOT.md`/README ยังสะท้อนทิศทาง Tok/Hei Hei สลับกัน ให้เอกสารนี้เป็นทิศทางใหม่ตามคำขอผู้ใช้ และปรับเอกสารเดิมพร้อม implementation ไม่ลบประวัติและ asset เก่าระหว่างออกแบบ

## 13. Acceptance และแผนส่งงาน

### ขั้น A — ตรวจแบบ (ผลงานในรอบนี้)

- concept ท่า Hei Hei 8 poses พร้อมต้นฉบับ PNG และ WebP preview
- interactive preview: desktop/Hub/motion settings; จำลองเล่นเพลง พิมพ์พร้อมเพลง โฟกัส ลูบ/อาหาร และลดการเคลื่อนไหว
- ต้นแบบแสดงชัดว่าใช้จังหวะจำลอง ไม่เชื่อมระบบเสียงหรือรับ global input
- สเปก UX, transition, priority, assets, accessibility, performance และ implementation mapping

### ขั้น B — vertical slice ในแอป

adult idle/typing/dance + resolver + capability flags + props + quick menu ใหม่ ก่อนขยายทุกหน้าจอและทุกวัย

### ขั้น C — ครบวงจร

Hub ใหม่, atlas จริง, migration, package verification, on-device QA, ท่ารองและ growth variants

### เกณฑ์ตรวจสำคัญ

1. เล่น → พิมพ์ → อุ้ม → ปล่อย → หยุดพิมพ์ → pause ต้องได้ activity ถูกต้องทุกจุด ไม่มี prop/transform ค้าง
2. Buffering/seek/source lost ไม่เต้นเหมือนยังได้ยินเสียง; local beat confidence ต่ำต้อง fallback ตาม label
3. Typing detection off และ Reduce Motion ต้องหยุด loop ที่เริ่มไปแล้ว ไม่รอเริ่มคลิปใหม่
4. ตัวละคร/เมนูไม่หลุดจอเมื่อเปลี่ยนขนาด เพิ่ม/ถอดจอ หรือย้าย Spaces
5. ไม่มี app activation/caret stealing จากการตอบสนองอัตโนมัติ; คลิกทะลุนอก hit region ได้
6. ฝากไฟล์หลายไฟล์ มีบางไฟล์ผิดพลาด ต้องแสดงผลจริง ไม่แสดงสำเร็จทั้งหมด
7. Animation ไม่เพิ่มรางวัล/เงิน/เวลาออนไลน์ด้วย callback ต่อเฟรม
8. Snapshot/visual QA ที่ 96/128/160/192 pt, light/dark, 1×/2× และ appearance accessibility
9. Unit tests ของ resolver ใช้ fake clock/seed; integration ตรวจ renderer cleanup และ state เมื่อ interrupt; แพ็กแอปแล้วตรวจ asset manifest
10. ประเมินความใกล้ต้นฉบับโดยดู silhouette, eye behavior, neck range และ comic timing แยกกัน ไม่ใช้แค่สีตรงเป็นเกณฑ์ผ่าน
