# Hey! — System Design

เอกสารออกแบบระบบฉบับเต็ม (v0.1) สำหรับแอปสัตว์เลี้ยงบนหน้าจอ macOS

## สถานะการพัฒนา

| Milestone | สถานะ | หมายเหตุ |
|---|---|---|
| S1 หน้าต่างโปร่งใส + SpriteKit | ✅ ทำแล้ว (ยังไม่ได้ยืนยันด้วยตาเรื่องคลิกทะลุ/ลากไฟล์) | click-through ใช้กรอบสี่เหลี่ยมรอบตัว ไม่ใช่รายพิกเซล |
| M1 สัตว์เลี้ยงเดิน + ท่าเมาส์ + FSM | ✅ | ลูบ/คลิก/อุ้ม/ตก/ลากไฟล์มาวาง |
| M2 stats, ฟักไข่, ให้อาหาร, XP, โต 5 ขั้น, บันทึก, offline catch-up | ✅ | เก็บเป็น JSON (`~/Library/Application Support/Hey/pet.json`) แทน SwiftData ไปก่อน เพราะยังมี entity เดียว ย้ายเมื่อมีหลายตาราง (M3+) |
| M3 ภารกิจรายวัน, เหรียญ, streak, ร้านค้า, หน้า Hub (SwiftUI) | ✅ | อาหารราคา>0 ต้องซื้อและใช้หมด ข้าวปั้นฟรี; ของตกแต่ง/สกินยังไม่ทำ (รอ asset); ไฟล์เซฟ M2 ถูกย้ายเป็นรูปแบบใหม่อัตโนมัติ |
| M4 ตั้งเตือน (parse ไทย/อังกฤษ, ซ้ำ, เลื่อน, เตือนซ้ำถ้าไม่รับ), Pomodoro, โน้ตแปะ (sticky ลอยบนจอ), hotkey ⌃⌥N/R/P/H | ✅ | แจ้งเตือนเป็นการ์ดบนจอ+เสียง ยังไม่ใช้ Notification Center (รันนอก .app bundle ไม่ได้) ย้ายตอนทำ .app |
| M5 ฝากไฟล์ (vault): ลากไฟล์/โฟลเดอร์/ข้อความ/ลิงก์มาวางที่สัตว์เลี้ยงหรือหน้า Hub, คัดลอกหรืออ้างอิง, ค้นหา/แท็ก/ปักหมุด/หมดอายุ, ลากกลับออก | ✅ | ทดสอบ ingest ผ่าน dev hook แล้ว (ลากจริงด้วยเมาส์ยังไม่ได้ลอง) |
| M6 เพลง: playlist (YouTube + ไฟล์ในเครื่อง), เล่น/ข้าม/สุ่ม/วนซ้ำ, ปุ่มมีเดียของคีย์บอร์ด, ลากลิงก์ YouTube มาวางที่สัตว์เลี้ยง | ✅ | S3 ผ่านแล้ว (ดูหมายเหตุด้านล่าง); ยังไม่ได้ลองฟังเสียงจริงและปุ่มมีเดียจริง |
| ปฏิกิริยาต่อสิ่งที่เกิดบนเครื่อง | ✅ ตรรกะทดสอบแล้ว · ท่าทางยังไม่ได้ดูด้วยตา | พิมพ์คีย์บอร์ด (ช้า/เร็ว, กระดิกตามจังหวะ, ไม่เดินหนี), แบตใกล้หมด (สั่น/ซีด) → วิกฤต (สั่นแรง+กะพริบแดง), เสียบปลั๊ก/แบตเต็ม, เครื่องร้อน (หอบ+ส้ม), ไม่ใช้เครื่อง 3 นาที (งีบ), ตื่นจากเครื่องหลับ (หาว), หันมองเมาส์ที่เข้าใกล้ — นับแค่จำนวนการกดแป้นจากตัวนับของระบบ (ไม่ต้องขอสิทธิ์ ไม่รู้ว่ากดอะไร) · ปิดแยกแต่ละกลุ่มได้ในแท็บ "สัตว์เลี้ยง" |
| Liquid Glass | ✅ | ฟองข้อความของสัตว์เลี้ยง, การ์ดเตือน/เสนอเพลง, เลขนับถอยหลัง, ตัวเล่นเพลง, การ์ด Pomodoro, สนามมินิเกม, ป้ายเหรียญ/streak ใช้ `glassEffect`; ปุ่มหลักใช้ `.glassProminent`; แถบข้างของ Hub ได้ glass จากระบบเอง · **ยังไม่ได้ดูด้วยตา** (เรนเดอร์ออกเป็นภาพยืนยันได้แค่ตัวอักษร ไม่เห็นวัสดุกระจก) |
| M6+ ตรวจเจอเพลง YouTube แล้วเสนอปุ่ม "เพิ่ม / เพิ่มและเล่น / ไม่เอา" | ✅ คลิปบอร์ดทดสอบจริงแล้ว · แท็บเบราว์เซอร์ยังไม่ได้ทดสอบ | ดูข้อจำกัดด้านล่าง |
| M6++ (ทดลอง) เสนอเพลงจาก Now Playing ของระบบ | ✅ อ่านค่าจริงได้ · ส่วนจับคู่แท็บเบราว์เซอร์ยังไม่ได้ทดสอบกับของจริง | ปิดไว้ก่อน ดูหมายเหตุด้านล่าง |
| เมนูแบบวงโค้ง (fan menu) รอบตัวสัตว์เลี้ยง | ✅ ตรรกะวางตำแหน่งทดสอบครบ (ทุกตำแหน่งจอ × ขนาดสัตว์ × จำนวนปุ่ม) · ยังไม่ได้ดูวัสดุกระจก/แอนิเมชันบนจอจริง | คลิกขวาที่สัตว์ หรือคลิกไอคอนแถบเมนู → ปุ่มกระจกกลมกางเป็นวงโค้งรอบตัว ปุ่มข้างกันห่างแค่ 8pt และวงในชิดตัวสัตว์; **วงโค้งหันไปทางที่มีที่ว่าง** (สัตว์อยู่ล่างจอ→ขึ้นบน, ขอบซ้าย/ขวา→หันเข้ากลางจอ, บนจอ→ห้อยลง) ถ้าที่แคบ (มุมจอ) จะแบ่งเป็น 2–3 วงซ้อนกันแทนการเว้นห่าง; หน้าต่างเมนูมีขนาดเท่าเนื้อหา · การ์ดสถานะสด · หน้า อาหาร (ภาพอาหาร+จำนวนคงเหลือ) / เพิ่มเติม · ปิดเมื่อคลิกข้างนอก/เลือกแล้ว/ไม่ใช้ 14 วินาที · ⌥+คลิกขวา หรือคลิกขวาที่ไอคอนแถบเมนู = เมนูข้อความแบบเดิม |
| ตรวจความเสถียรและการใช้งาน | ✅ | โหลดเซฟแบบทนความเสียหาย (รายการเสียข้าม, หมวดเสียใช้ค่าเริ่มต้น), สำรอง 3 รุ่น, บันทึกแบบหน่วง 0.4 วิ, เปิดซ้อนไม่ได้ (lock ต่อโฟลเดอร์ข้อมูล), SIGTERM/ปิดเครื่องบันทึกก่อนออก, หยุดอัดก่อนออก, กล้องไม่ crash เมื่อยังไม่พร้อม, YouTube ออฟไลน์/ตัวเล่นล่มแจ้งเตือน, AppleScript มี timeout, สัตว์ไม่ค้างในท่าอุ้มและไม่หลุดจอ · คู่มือแรกใช้, ข้อความอาหาร/ไข่ชัดขึ้น, Hub จัดกลุ่ม + หน้าการตั้งค่า, Esc ปิดเมนู |
| ไม่ใช้ emoji ใน UI | ✅ | ทั้งแอปใช้ SF Symbols แทน (ฟองข้อความมีไอคอนนำหน้า) และใช้ภาพอาหารที่ Codex วาดใน `Resources/Icons/food_*.png` (ข้าว, คุกกี้, ผลไม้, น้ำผึ้ง) ตัวเงินเขียนเป็นคำว่า "เหรียญ" |
| ไฟล์ 2 ระบบ: ฝากเก็บ (vault ถาวร) + ถาดพักไฟล์ (shelf ชั่วคราว) | ✅ ตรรกะทดสอบแล้ว · การลากจริงยังไม่ได้ลอง | ลากอะไรเข้าหาสัตว์เลี้ยง → มีช่องกระจก 2 ช่องโผล่เหนือหัว (ฝากเก็บ / พักไว้ลากต่อ) ปล่อยลงช่องที่ต้องการ; ปล่อยลงตัวสัตว์ตรงๆ ใช้ค่าเริ่มต้น (ตั้งได้ ปกติ=ฝากเก็บ); ถาดพักเป็นการ์ดมุมซ้ายล่างจอ ลากรายการออกไปวางที่ไหนก็ได้ (เอาออกเองหลังลากสำเร็จ, ล้างเองใน 24 ชม., เก็บแค่อ้างอิงไม่ก็อปปี้, สูงสุด 30 ชิ้น), ย้ายเข้า vault ได้; ตรวจการลากจากการเปลี่ยนของ drag pasteboard ตอนกดเมาส์ค้าง (ไม่ต้องขอสิทธิ์) — แปลคำว่า "2 ระบบ" จากข้อความ "ฝากไฟล์ ลากไฟล์" ถ้าหมายถึงอย่างอื่นให้บอก |
| โลโก้/ไอคอน = หัว Hei Hei | ✅ | ภาพหลักวาดโดย Codex (`Resources/Logo/heihei_head.png`, `heihei_icon.png`, `heihei_mark.png`; พรอมต์ใน `docs/LOGO_GENERATION.md`) เส้นขอบหนาเข้ากับ sprite → `AppIcon.icns` และ `docs/logo.png` สร้างโดย `scripts/make-icon.sh` (ตัวหนังสือ "Hey!" วาดด้วยโค้ด); ไอคอนบนแถบเมนูยังใช้เงาที่วาดด้วยโค้ด (`LogoArt.swift`) เพราะภาพ mark ของ Codex ย่อเหลือ 18px แล้วเป็นก้อนอ่านไม่ออก; ถ้าไม่มีไฟล์ใน `Resources/Logo` สคริปต์ใช้ภาพที่วาดด้วยโค้ดแทน |
| ชื่อเพลงวิ่งบนแถบเมนู | ✅ | แถบเมนูตัวที่สอง (ไอคอน ♪ + ข้อความ กว้าง ~170pt) โผล่ตอนมีเพลง แสดง "ชื่อ — ศิลปิน" ถ้ายาวเกินจะวนเลื่อนต่อเนื่อง (Core Animation ทำงานบน compositor ไม่กิน CPU ของแอป) ขอบเบลอเข้า-ออก; หยุดชั่วคราวจะเปลี่ยนไอคอนเป็น ⏸ และหยุดเลื่อน; โหมดประหยัด/พัก ข้อความอยู่นิ่ง; คลิกเปิดเมนูควบคุมเพลง; ปิดได้ใน Hub › เพลง |
| M7 ถ่ายรูป/อัดวิดีโอ: ภาพทั้งจอ (นับถอยหลัง), เลือกพื้นที่, อัดหน้าจอ (+เสียงระบบ/ไมค์), กล้อง (รูป/วิดีโอ), แกลเลอรี | ✅ เขียนและ build ผ่าน | **ยังไม่ได้ทดสอบจริง** — เครื่องนี้ยังไม่ให้สิทธิ์ Screen Recording/กล้องแก่แอป (ดู docs ด้านล่าง) |
| PowerPolicy (ข้ามไปจาก M1) | ✅ | ระดับ เต็มกำลัง/สมดุล/ประหยัด/พัก ตามแบต, Low Power, ความร้อน, จอดับ/ล็อก, แอปเต็มจอ, ไม่ได้ใช้เครื่อง; นาฬิกา 10 วินาทีแยกจากการวาด; ตัวเลือกเปิดตอนล็อกอิน |
| M8 ท่าทัชแพด (ปัด/หมุน 2 นิ้ว, pinch ปรับขนาด, ดับเบิลคลิก), มุมจอ, ตั้งค่าจับคู่ท่า→คำสั่ง | ✅ เขียนและ build ผ่าน | **ยังไม่ได้ลองกับทัชแพดจริง** — ทิศของการปัดแปลงจาก `isDirectionInvertedFromDevice` ตามที่เข้าใจ ถ้ากลับด้านให้สลับคำสั่งในแท็บ "ท่าทาง" (มีช่อง "ท่าล่าสุดที่รู้จัก" ไว้เช็ก) |
| M9 ขัดเกลา: achievements (19 อย่าง) + สถิติตลอดชีพ, มินิเกม (เหรียญจำกัด 3 รอบ/วัน), ปฏิกิริยาตามบริบท (ดึก/กลับมาหลังหายไป/นั่งนานเกิน 90 นาที), เดิน/ยืนบนหน้าต่างอื่น (โตเป็นวัยรุ่นขึ้นไป), ท่ากิน, Hub แบบแถบด้านข้าง | ✅ โค้ดเสร็จ | ยังไม่ได้ลองด้วยตา โดยเฉพาะการเดินบนหน้าต่าง |
| สายพันธุ์แรก | **Hei Hei** (ไก่ตาเหล่จาก Moana, fan art ใช้ส่วนตัว) | ✅ ภาพครบ 21 ไฟล์ | ภาพอยู่ที่ `Resources/Sprites/heihei/<ขั้น>_<ท่า>.png` (21 ไฟล์ ผ่านการปรับมาตรฐานแล้ว: ผืนผ้าใบ 1024², เท้าอยู่ที่ y=861 ทุกภาพ, จัดกึ่งกลาง, ขั้นโตเต็มวัยย่อลง 0.72× ให้สูงใกล้เคียงขั้นอื่น เพราะแอปขยายตามขั้นเองอยู่แล้ว; ต้นฉบับจาก Codex เก็บไว้ที่ `Resources/Sprites/_originals/heihei/`); ไฟล์ที่ยังไม่มีจะใช้ภาพก่อนหน้าหรือตัว blob สีมินต์แทนอัตโนมัติ — blob เก็บไว้เป็นสายพันธุ์สำรอง |

**หมายเหตุ asset:** ภาพ Hei Hei เป็นของ Disney ใช้ได้เฉพาะในเครื่องส่วนตัว ถ้าจะแจกจ่ายต้องเปลี่ยนเป็นตัวละครต้นฉบับ (โครงสร้างสายพันธุ์รองรับการเปลี่ยนอยู่แล้ว: `species` ในไฟล์เซฟ + โฟลเดอร์ภาพ)

**ผลวัดพลังงาน (release build, อ่านจาก `top`, เครื่องที่ใช้งานอยู่ระหว่างวัด จึงมีสัญญาณรบกวน ±1%)** — สัตว์ยืนนิ่ง: 1 fps ≈ 1–2% · 2 fps ≈ 1% · 4 fps ≈ 1.5% · 10 fps ≈ 3% · 30 fps ≈ 5.5% CPU (ราว 0.15% ต่อ 1 fps บวกค่าคงที่ราว 1%); โหมดพัก (หยุดวาด) 0.0% และ RAM ลดจาก ~150 MB เหลือ ~33 MB จึงตั้งเฟรมเรตตอนนิ่ง/ตอนเคลื่อนที่เป็น เต็มกำลัง 6/24 · สมดุล 5/18 · ประหยัด 3/12 — ยังไม่ได้วัดด้วย `powermetrics` (ต้อง sudo) และค่าคงที่ ~1% ที่ไม่ขึ้นกับเฟรมเรตยังไม่ได้สืบสาเหตุ
- ตรวจแอปเต็มจอด้วยหน้าต่างของแอปอื่นที่ขนาดเท่าจอ (รวมแถบเมนู); ตรวจการแชร์จอ/Focus ไม่ได้ด้วย API สาธารณะ จึงยังไม่รองรับ — ใช้ปุ่ม "ซ่อน" ในเมนูแทน

**เรื่องสิทธิ์ (M7):** macOS ผูกสิทธิ์กับตัวตนของแอป จึงเพิ่ม `Info.plist` ฝังในไฟล์รัน (bundle id `com.cdimac.hey` + คำอธิบายกล้อง/ไมค์ ไม่งั้นระบบจะปิดแอปทันทีที่แตะกล้อง) และสคริปต์ `scripts/make-app.sh` สร้าง `Hey.app` ถ้ามีใบรับรอง Apple Development ให้ตั้ง `HEY_SIGN_IDENTITY` ไม่งั้นเซ็นแบบ ad-hoc ซึ่งต้องอนุญาตสิทธิ์ใหม่ทุกครั้งที่ build (เครื่องนี้ไม่มีใบรับรองที่ใช้เซ็นได้ — `security find-identity` ว่าง)
- หน้าต่างของ Hey! ทั้งหมด (สัตว์เลี้ยง, นับถอยหลัง, โน้ต, Hub) ถูกกันออกจากภาพที่จับ ด้วย `excludingApplications`

**การตรวจเพลง YouTube (ข้อจำกัดที่ตั้งใจ):** macOS ไม่มี API สาธารณะให้ถามว่า "ตอนนี้แอปไหนกำลังเล่นอะไร" (ตัว MediaRemote เป็น API ส่วนตัว และถูกจำกัดตั้งแต่ macOS 15.4) จึงใช้ 2 ทางที่ไม่ต้องพึ่งมัน: (1) ลิงก์ที่เพิ่งคัดลอก — ข้ามข้อความที่ตัวจัดการรหัสผ่านทำเครื่องหมายไว้ และไม่เก็บอะไรที่ไม่ใช่ลิงก์ YouTube; (2) แท็บหน้าสุดของ Safari/Chrome/Arc/Brave/Edge ผ่าน AppleScript (ต้องอนุญาตระบบอัตโนมัติ, ปิดไว้ก่อน, อ่านเฉพาะ URL+ชื่อ ทุก ~6 วินาทีเมื่อเบราว์เซอร์เป็นแอปหน้าสุด) — รู้ว่า "แท็บนี้เป็นหน้าวิดีโอ YouTube" แต่ไม่รู้ว่ากำลังเล่นอยู่หรือไม่, ไม่เห็นแท็บเบื้องหลัง, Firefox ไม่รองรับ

**Now Playing ของระบบ (ทดลอง):** ทดสอบพบว่าโปรแกรมที่ Apple เซ็นเอง (เช่น `/usr/bin/swift`, `/usr/bin/perl`) อ่าน MediaRemote ได้ แต่แอปที่เซ็นเองอ่านได้แค่ค่าว่าง (ยืนยันบน macOS 26.6 ด้วยไบนารี ad-hoc ตัวเดียวกัน) จึงให้ `/usr/bin/perl` โหลด `libheynp.dylib` (ไลบรารี C เล็กๆ ที่ SwiftPM สร้าง) แล้วพิมพ์ JSON หนึ่งบรรทัด ทุก ~4 วินาทีเมื่อเปิดใช้ แล้วจับคู่ชื่อเพลงที่กำลังเล่น (rate > 0) กับแท็บเบราว์เซอร์ที่เปิดหน้า YouTube ชื่อตรงกัน เพื่อเอาลิงก์ (ระบบให้ชื่อเพลง ไม่ให้ URL) · ข้อจำกัด: เป็น API ส่วนตัว Apple ปิดได้ทุกเมื่อ, โฆษณาชื่อไม่ตรงแท็บจึงไม่ถูกเสนอ, ต้องอนุญาตระบบอัตโนมัติ, Firefox ไม่มีแท็บให้อ่าน · ไม่ควรแจกจ่ายแอปที่ใช้ทางนี้

**ผล spike S3 (YouTube ใน WKWebView ที่ซ่อน):** เล่นได้ แต่ต้องทำ 3 อย่าง (1) หน้าเว็บต้องมี origin เป็น https จริง — ใช้ `https://com.cdimac.hey`; ถ้าใช้ `www.youtube.com` เองจะได้ error 152 (2) หน้าต่างผู้เล่นต้องเป็น 200×200 และมี 1 พิกเซลอยู่บนจอ — ถ้าวางนอกจอทั้งหมด WebKit จะแช่แข็งหน้าและตัวนับเวลาหยุด (3) ถือ `beginActivity` ระหว่างเล่นกัน App Nap
- รองรับเฉพาะลิงก์วิดีโอเดี่ยว (ลิงก์ playlist ของ YouTube ยังไม่รองรับ) · วิดีโอที่ปิดการฝังจะข้ามไปเพลงถัดไปอัตโนมัติ · ต้องออนไลน์ และ YouTube อาจเปลี่ยนกฎการฝังได้ทุกเมื่อ

ค่าบาลานซ์ที่ใช้จริง (อยู่ใน `Balance.standard`): ออกจากขั้นต้องใช้ XP hatchling 150 → child 400 → teen 1000 → adult (ตัวเลข 2400 ในตารางข้อ 4.1 ยังไม่ใช้ เก็บไว้สำหรับกิ่งวิวัฒนาการ)

## 0. การตัดสินใจที่ล็อกแล้ว

| หัวข้อ | ข้อสรุป | ผลต่อการออกแบบ |
|---|---|---|
| ผู้ใช้ | ใช้ส่วนตัว ไม่แจกจ่าย | ปิด App Sandbox ได้, ไม่ต้อง notarize, ข้อจำกัด ToS ของ YouTube เป็นความเสี่ยงส่วนตัว (ดู 8.4) |
| แพลตฟอร์ม | macOS เท่านั้น | ใช้ native stack เต็มที่ (Swift) |
| ภาพ | **2D ก่อน** (sprite) ส่วน 3D เก็บไว้เป็นอนาคต | ใช้ SpriteKit + sprite sheet; ต้องมี "สัญญา" ของ asset (7.3) เพื่อสลับสไตล์/เพิ่ม 3D ทีหลังได้ |
| ขอบเขต | ออกแบบให้ครอบคลุมก่อน | เอกสารนี้ครอบคลุมทุกระบบ + เสนอลำดับสร้าง |

**Deployment target: macOS 15 (Sequoia) ขึ้นไป** (`SCRecordingOutput` ใช้ได้ตั้งแต่ 15) Liquid Glass ใช้บน macOS 26 ผ่านตัวห่อ `heyGlass`/`GlassGroup` ใน `GlassStyle.swift` ส่วน macOS 15 ใช้วัสดุโปร่งแสงแทน CI รัน build และเทสต์บน macos-15 และ macos-26 ดูหน้าตาแบบ macOS 15 บนเครื่องใหม่ได้ด้วย `HEY_DEV=1 HEY_DEV_NO_GLASS=1`

---

## 1. Tech Stack

| ชั้น | เลือก | เหตุผล |
|---|---|---|
| ภาษา | Swift 6 (strict concurrency) | actor แยก state ชัดเจน |
| UI ทั่วไป | SwiftUI (Hub, ตั้งค่า, popover) | |
| หน้าต่างสัตว์เลี้ยง | AppKit `NSPanel` โฮสต์ `SKView` (SpriteKit) | SwiftUI ควบคุม level/click-through ไม่พอ |
| 2D render | **SpriteKit** (`SKView` โปร่งใส, `SKTextureAtlas`) | รองรับพื้นหลังโปร่งใสดี เบากว่า 3D มาก เล่น sprite sheet/frame animation ได้ตรง ๆ; ถ้าต่อไปจะทำ 3D ค่อยเพิ่ม RealityKit เป็น renderer ตัวที่สอง |
| Persistence | SwiftData | เพียงพอสำหรับใช้คนเดียว ถ้าติดข้อจำกัด migrate ไป GRDB |
| Gesture | `NSEvent` (mouse/trackpad: scroll, magnify, rotate, pressure) + Carbon hotkey | ไม่ต้องใช้กล้อง/ML |
| กล้อง/ไมค์ (เฉพาะอัดรูป/วิดีโอ) | AVFoundation (`AVCaptureSession`) | ใช้เมื่อผู้ใช้สั่งถ่ายเท่านั้น |
| จับภาพ/วิดีโอหน้าจอ | ScreenCaptureKit (`SCScreenshotManager`, `SCRecordingOutput`) | |
| แจ้งเตือน | `UserNotifications` + scheduler ของเราเอง | |
| เพลง | `WKWebView` (YouTube IFrame API) + `AVPlayer` (ไฟล์ในเครื่อง) | |
| Hotkey ทั่วระบบ | `KeyboardShortcuts` (SPM) หรือ Carbon `RegisterEventHotKey` | |
| Login item | `SMAppService` | เปิดแอปอัตโนมัติ |
| ทดสอบ | Swift Testing + XCTest (UI) | |

---

## 2. สถาปัตยกรรมภาพรวม

```
┌──────────────────────────── Hey.app (LSUIElement: ไม่มี Dock icon) ────────────────────────────┐
│                                                                                                │
│  Presentation          PetWindow (NSPanel+SpriteKit)   HubWindow (SwiftUI)   MenuBarExtra   Overlays   │
│                              ▲                        ▲                    ▲                   │
│  ─────────────────────────────┼────────────────────────┼────────────────────┼───────────────── │
│  Input Layer      Pointer ─┐  │                        │                    │                   │
│                   Hotkey ──┼─► GestureRecognizer ─► InputEventBus ─► ActionMapper               │
│   DragDrop ──┘   (state machine)                                  │                   │
│  ───────────────────────────────────────────────────────────────────────────┼────────────────── │
│  Domain (pure Swift, ไม่พึ่ง UI)                                             ▼                   │
│   PetEngine ─ StatsSystem ─ GrowthSystem ─ BehaviorFSM ─ QuestSystem ─ EconomySystem             │
│                                                                                                │
│  Features (ปลั๊กอินตาม protocol `Feature`)                                                      │
│   Reminders │ FileVault │ Capture │ MusicPlayer │ Pomodoro │ Notes │ …                          │
│  ───────────────────────────────────────────────────────────────────────────────────────────── │
│  Platform Services   CameraManager │ ScreenService │ Scheduler │ PermissionCenter │ Store(SwiftData) │ Clock │
└────────────────────────────────────────────────────────────────────────────────────────────────┘
```

หลักการ:
1. **Domain ไม่รู้จัก UI/OS** — `PetEngine` รับ event เข้า ส่ง state ออก เทสต์ได้ล้วน ๆ โดยฉีด `Clock` ปลอม
2. **ทุก input เป็น event เดียวกัน** — เมาส์/trackpad hotkey ลากวาง ออกมาเป็น `InputEvent` เหมือนกัน
3. **Feature เป็นโมดูลแยก** — ลงทะเบียนผ่าน protocol ปิด/เปิดแต่ละตัวได้ในตั้งค่า
4. **Platform Services เป็นเจ้าของทรัพยากรที่ชนกันได้** — เช่นกล้องมี `CameraManager` ตัวเดียว

```swift
protocol Feature {
    var id: String { get }
    var requiredPermissions: [Permission] { get }
    func start(context: FeatureContext) async
    func stop() async
    func handle(_ action: Action) async        // รับ action จาก ActionMapper
    var petInteractions: [PetInteraction] { get } // เช่น drop target, เมนูวงกลม
}
```

---

## 3. ระบบหน้าต่าง (Window System)

| หน้าต่าง | ชนิด | คุณสมบัติ |
|---|---|---|
| **PetWindow** | `NSPanel` (`.nonactivatingPanel`, borderless) | พื้นหลังโปร่งใส, `level = .floating`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`, ไม่แย่ง focus |
| **Hub** | `Window` SwiftUI | ร้านค้า, ภารกิจ, vault, playlist, ตั้งค่า |
| **MenuBarExtra** | SwiftUI | เปิด Hub, โหมดเงียบ, ซ่อน/แสดงสัตว์เลี้ยง, ออก |
| **Overlay** | `NSPanel` ชั่วคราว | นับถอยหลังถ่ายภาพ, เลือกพื้นที่แคปจอ, bubble ข้อความ |

**Click-through แบบเลือกพื้นที่:** PetWindow ขนาดเท่าทั้งจอ (หรือ region ใหญ่พอให้สัตว์เดิน) ทำ `hitTest` ว่า pixel ใต้เมาส์โปร่งใสหรือไม่ แล้วสลับ `ignoresMouseEvents` ตามตำแหน่ง ทางเลือกคือหน้าต่างเล็กขนาดเท่าตัวสัตว์แล้วย้ายตามตัว (ประหยัด GPU กว่า แต่ drag-drop ไฟล์จากภายนอกต้องมี drop zone รอบตัว) — **ตัดสินใจใน spike S1**

**หลายจอ:** สัตว์เลี้ยงอยู่ได้ทีละจอ ย้ายข้ามจอได้โดยเดินชนขอบ (`NSScreen.screens`)

**ซ่อนอัตโนมัติ:** ตอนแชร์หน้าจอ/เต็มจอ/Do Not Disturb (ตรวจ `NSWorkspace` + `SCShareableContent`) เปิด-ปิดได้ในตั้งค่า

---

## 4. Pet Domain

### 4.1 Lifecycle

```
Egg ──(อุ่นครบ)──► Hatchling ──► Child ──► Teen ──► Adult
                                                 └─► (แตกกิ่งรูปร่างตามสไตล์การเลี้ยง)
```

| ขั้น | XP สะสมที่ต้องใช้ (เริ่มต้น) | ขนาดตัว (สเกล sprite) | ปลดล็อก |
|---|---|---|---|
| Egg | อุ่น 100 แต้ม | 0.5 | ฟักไข่ |
| Hatchling | 150 | 0.6 | กินอาหารพื้นฐาน |
| Child | 400 | 0.8 | ภารกิจรายวัน, ของเล่น |
| Teen | 1000 | 1.0 | เดินบนขอบหน้าต่าง |
| Adult | 2400 | 1.2 | วิวัฒนาการแตกกิ่ง, ท่าพิเศษ |

ตัวเลขเป็นค่าตั้งต้นใน `balance.json` ปรับได้โดยไม่ build ใหม่ ("ตัวโตขึ้น" = เปลี่ยนสเกล + เปลี่ยน sprite set ตามขั้นที่กำหนดไว้ใน model manifest)

### 4.2 Stats

| Stat | ช่วง | ลดตามเวลา | เพิ่มโดย | ผลเมื่อต่ำ |
|---|---|---|---|---|
| Hunger (ความอิ่ม) | 0–100 | −4/ชม. | ให้อาหาร | ขออาหาร, XP ลด 50% |
| Mood | 0–100 | −2/ชม. | เล่น, ลูบ, ภารกิจ | ซึม, ไม่ทำท่าพิเศษ |
| Energy | 0–100 | −3/ชม. ตอนตื่น | นอน (+10/ชม.) | หลับเอง |
| Bond | 0–1000 | ไม่ลด | ทุกกิจกรรม, เปิดแอปรายวัน | ปลดล็อกกิ่งวิวัฒนาการ |

**กฎสำคัญ:** ไม่มีการตาย/ป่วย ค่าต่ำสุดคือ "เศร้า/หิว" และฟื้นได้ทุกเมื่อ

**Offline catch-up:** ตอนเปิดแอปคำนวณค่าที่ลดจาก `lastTickAt` โดยจำกัดเพดานเทียบเท่า **8 ชม.** กัน "กลับมาแล้วรู้สึกผิด" และกันโกงด้วยการปรับนาฬิกา (ถ้าเวลาย้อนหลังให้ถือว่า delta = 0)

### 4.3 ฟักไข่

อุ่นด้วย: ไข่อยู่บนจอขณะแอปทำงาน (+1/นาที สูงสุด 60/วัน) คลิกลูบ (+2 ต่อครั้ง วันละ 10) และทำภารกิจ (+20) → ฟักได้ในราว 2–3 วัน มีแอนิเมชันสั่น/ร้าวตาม progress

### 4.4 ให้อาหาร

| ประเภท | ตัวอย่าง | Hunger | Mood | XP | หมายเหตุ |
|---|---|---|---|---|---|
| พื้นฐาน | ข้าวเม็ด | +20 | 0 | 2 | ฟรี ไม่จำกัด (cooldown 10 นาที) |
| ขนม | คุกกี้ | +10 | +15 | 3 | ซื้อด้วยเหรียญ |
| พิเศษ | ผลไม้หายาก | +30 | +20 | 8 | ได้จากภารกิจ/ร้านค้า |

มี "อาหารโปรด" ต่อตัว (สุ่มตอนฟัก) ได้โบนัส ×2 วิธีให้: ลากไอคอนจากกระเป๋าไปวางที่สัตว์เลี้ยง (ผ่านชั้น Pointer gestures) หรือเลือกจากเมนูวงกลม

### 4.5 ภารกิจรายวัน

- สุ่ม 3 ข้อ/วัน (รีเซ็ตตี 4 ตามเวลาท้องถิ่น) จากคลัง `quests.json`
- ชนิด: `feed(n)`, `pet(seconds)`, `reminder(n)`, `pomodoro(n)`, `capture(n)`, `playMusic(minutes)`, `openToday`
- รางวัลเหรียญ 10–30 + XP 5–15, ครบ 3 ข้อได้โบนัสกล่อง
- **Streak:** เปิดแอป+ทำอย่างน้อย 1 ภารกิจต่อวัน ครบ 7 วัน ได้ไอเทมพิเศษ ขาดวันเดียวไม่รีเซ็ตเป็น 0 แต่ลดครึ่ง

ภารกิจรับ event จาก `InputEventBus`/Feature ผ่าน `QuestSystem.record(event)` — ไม่มี feature ใดต้องรู้จักระบบ quest โดยตรง

### 4.6 Economy

เหรียญจากภารกิจ/streak/มินิเกม ใช้ซื้ออาหาร ของตกแต่ง สกินสี ของเล่นในร้านค้า ไม่มีการเติมเงิน ไม่มี loot box

### 4.7 Evolution กิ่ง

ที่ Adult ระบบดู "โปรไฟล์การเลี้ยง" 4 ค่า: สัดส่วนอาหารหวาน, เวลาเล่น, จำนวนภารกิจโฟกัส/Pomodoro, bond → เลือกกิ่ง (เช่น Chubby, Playful, Scholar, Balanced) แต่ละกิ่งเป็น model/สกิน/ท่าพิเศษต่างกัน

---

## 5. Behavior & Movement

### 5.1 FSM

```
idle ⇄ walk ⇄ sit ⇄ sleep
 │      │
 ├──► eat / play / beg (ขอความสนใจ) / react(petted, startled, waved) / carry(file) / holdCamera / holdNote
 └──► drag (ผู้ใช้อุ้ม) ──► fall ──► land
```

- เลือกสถานะถัดไปแบบถ่วงน้ำหนักตาม stats + เวลา (กลางคืนง่วงง่าย) + บริบท (ผู้ใช้ idle นาน → เข้ามาชวนเล่น)
- ทุกสถานะมี `minDuration`, `interruptible`, และ `animationClip` ตามสัญญา model (7.3)
- ผู้ใช้พิมพ์เร็ว/อยู่ในแอปโฟกัส → ลด activity เหลือ idle/sit (อ่านจากความถี่ key events ผ่าน `CGEventSource` ไม่ต้องบันทึกตัวอักษร) เปิด/ปิดได้

### 5.2 การเคลื่อนที่

- พื้นผิวเดิน: ขอบล่างจอ (เหนือ Dock ใช้ `NSScreen.visibleFrame`), ขอบบนของหน้าต่างอื่น
- **ตำแหน่งหน้าต่างอื่น:** `CGWindowListCopyWindowInfo` ให้ **bounds ได้โดยไม่ต้องขอสิทธิ์** (ชื่อหน้าต่างเท่านั้นที่ต้อง Screen Recording) จึงเดินบนขอบหน้าต่างได้โดยไม่ต้องขอสิทธิ์เพิ่ม — โพลล์ 4 Hz เฉพาะตอนสัตว์เลี้ยงอยู่บนหน้าต่าง
- การเคลื่อนที่ทำเป็น "ตัวละคร" ในระบบ fixed-timestep ของ domain ส่งตำแหน่งให้ view วาด
- พลังงานต่ำ → ลดการเคลื่อนที่ เพื่อประหยัดทั้ง CPU และให้ดูมีชีวิต

---

## 6. Gesture Control Layer (ไม่ใช้กล้อง)

ท่าทางทั้งหมดมาจากอุปกรณ์ที่มีอยู่แล้ว: **เมาส์ / trackpad / คีย์บอร์ด** ไม่มีการเปิดกล้องและไม่มี ML ทำให้ไม่ต้องขอสิทธิ์ Camera, ไม่กินแบตเพิ่ม และแม่นยำกว่า

### 6.1 Pipeline

```
NSEvent (mouse/trackpad) ─┐
Global hotkeys ───────────┼─► GestureRecognizer (state machine) ─► InputEvent.gesture(name, phase, value?)
Drag & drop events ───────┘                                              │
                                                                          ▼
                                                      InputEventBus ─► ActionMapper ─► Feature.handle(Action)
```

### 6.2 ท่าที่รองรับ

| กลุ่ม | ท่า | วิธีตรวจ | Action ตัวอย่าง |
|---|---|---|---|
| **บนตัวสัตว์เลี้ยง** | คลิก | `mouseDown/Up` | ทัก / ปลุก |
| | ดับเบิลคลิก | clickCount = 2 | เปิดเมนูวงกลม |
| | ลูบ (เมาส์ไปมาช้า ๆ เหนือตัว) | ระยะทางสะสม + ทิศกลับด้าน ≥ N ครั้ง ความเร็วต่ำ | เพิ่ม mood/bond |
| | อุ้ม (กดค้าง + ลาก) | `mouseDragged` | ย้ายตำแหน่ง, ปล่อยแล้วตก |
| | ดีด/ปาไป (ลากเร็วแล้วปล่อย) | ความเร็วตอนปล่อย | สัตว์กระเด็น/เด้งขอบจอ |
| | เขย่า (ลากสลับทิศเร็ว) | จำนวนการกลับทิศ/วินาที | ตกใจ/เวียนหัว |
| | คลิกขวา / Control-click | | เมนูบริบท |
| **Trackpad** | ปัด 2 นิ้วบนตัวสัตว์ | `scrollWheel` ขณะ hover | เพลงก่อนหน้า/ถัดไป |
| | pinch บนตัวสัตว์ | `magnify` event | ปรับขนาดสัตว์เลี้ยง |
| | หมุน 2 นิ้ว | `rotate` event | หมุนตัว/เปลี่ยนมุมมอง (ถ้ามี) |
| | Force Click / ปัด 3 นิ้ว | `pressure` / เมนูระบบ | (ทางเลือก) |
| **ลาก&วาง** | ลากไฟล์/ข้อความ/ลิงก์มาวางที่ตัว | `NSDraggingDestination` | เก็บเข้า Vault |
| | ลากอาหารจากกระเป๋าไปวาง | ภายในแอป | ให้อาหาร |
| **Hotkey ทั่วระบบ** | เช่น ⌥Space เรียกสัตว์เลี้ยง / ⌥M ซ่อน-แสดง / ⌥N โน้ตด่วน / ⌥R ตั้งเตือนด่วน | `RegisterEventHotKey` | ใช้ได้โดยไม่ต้องสิทธิ์ Accessibility |
| **Hot corner / ขอบจอ** | เมาส์ชนมุมจอค้าง 0.5 วินาที | ตำแหน่งเมาส์จาก global monitor | เรียกสัตว์เลี้ยงมาที่เมาส์ |

### 6.3 การตรวจจับ (Recognizer)

- รับเหตุการณ์ผ่าน `NSEvent` ใน PetWindow (local) — ไม่ต้องสิทธิ์ใด ๆ
- **Global monitor** (เฉพาะ hot corner และ "ผู้ใช้ idle") ใช้ `NSEvent.addGlobalMonitorForEvents` ซึ่ง**ต้องสิทธิ์ Input Monitoring/Accessibility สำหรับ key events** แต่ mouse-moved ทั่วไปใช้ได้โดยไม่ต้องสิทธิ์ในหลายกรณี ถ้าไม่ต้องการสิทธิ์เลย ให้ใช้ `NSEvent.mouseLocation` โพลล์ที่ 10 Hz เฉพาะตอนเปิดฟีเจอร์ hot corner
- ใช้ state machine ต่อท่า (idle → candidate → recognized → cooldown) พร้อมค่าพารามิเตอร์ใน `gestures.json` (ระยะ, ความเร็ว, จำนวนครั้ง, เวลา) ปรับได้ไม่ต้อง build ใหม่
- ท่าที่ชนกัน (คลิก vs ลาก vs ลูบ) ใช้กฎลำดับ: ขยับเกินระยะ 4 pt = ลาก; ขยับช้า + กลับทิศ = ลูบ; อื่น ๆ = คลิก

### 6.4 Action mapping

ตาราง `gesture → action` เก็บใน SwiftData แก้ได้ในตั้งค่า ตัวอย่าง: `scrollRight(onPet) → music.next`, `doubleClick(onPet) → petMenu.open` ท่าเดียวกันเปลี่ยนความหมายตามบริบท (เช่น เมื่อมีเตือนกำลังเด้ง คลิกสัตว์เลี้ยง = snooze)

### 6.5 พลังงาน

- ไม่มีกล้อง ไม่มี ML: ต้นทุนเกือบเป็นศูนย์ (event-driven ไม่มี polling ยกเว้นโหมด hot corner 10 Hz)
- ท่าทางทำงานได้ทุก tier ของ PowerPolicy ไม่ต้องปิดเมื่อแบตต่ำ

### 6.6 ข้อจำกัด

- ท่าบน trackpad ใช้ได้เมื่อเมาส์ชี้อยู่บนตัวสัตว์เลี้ยง (event ส่งถึงหน้าต่างที่อยู่ใต้ cursor) ถ้าใช้เมาส์ธรรมดา (ไม่มี multitouch) จะเหลือคลิก/ลาก/ลูบ/scroll wheel
- ท่าที่ขึ้นกับพื้นที่ (ลูบ/ลาก) ต้องมีหน้าต่างรับ event ตรงตำแหน่งตัวสัตว์ (ผูกกับ click-through ใน S1)

---

## 7. 2D Sprite Pipeline

### 7.1 การเรนเดอร์
- `SKView` โปร่งใส (`allowsTransparency = true`, scene `backgroundColor = .clear`) ใน `NSPanel`
- 1 `SKSpriteNode` ต่อสัตว์เลี้ยง + node ของ prop (อาหาร, โน้ต, กล้อง) เล่น frame animation จาก `SKTextureAtlas`
- FPS จริงของแอนิเมชันคือ 8–12 fps (สไตล์ frame-by-frame) ตั้ง `preferredFramesPerSecond` ตามนั้น ไม่ต้อง 30 → **ประหยัดพลังงานกว่า 3D ชัดเจน** (ประเมิน active ≈ 0.1–0.4 W, idle ≈ 0.02–0.1 W; ต้องวัดจริง)
- Render-on-demand: หยุด loop (`isPaused = true`) เมื่อสัตว์อยู่ท่านิ่งและไม่มี animation

### 7.2 การสร้าง asset (pipeline)
```
Prompt/สั่ง Codex gen ภาพ ─► ภาพต้นฉบับ (PNG โปร่งใส) ─► ตัดพื้นหลัง/จัดเฟรม ─► sprite sheet / เฟรมแยก
        ─► ใส่ใน Resources/Sprites/<species>/<stage>/<clip>/NN.png ─► manifest.json ─► SKTextureAtlas
```
- ข้อจำกัดของภาพที่ AI สร้าง: **ความสม่ำเสมอระหว่างเฟรมไม่แน่นอน** (ตัวละครเพี้ยนเล็กน้อยทุกภาพ) จึงต้อง
  1. เริ่มจาก **character sheet อ้างอิง 1 ภาพต่อสายพันธุ์/ขั้น** แล้วใช้เป็นภาพอ้างอิงตอนสั่งสร้างท่าอื่น
  2. ใช้เฟรมน้อยและสไตล์ที่ทนความไม่เป๊ะ (pixel art / ภาพวาดเรียบ) เช่น 4–6 เฟรมต่อคลิป
  3. มี script ตัดพื้นหลัง/จัดจุดยึด (pivot) ให้ตรงกันทุกเฟรม และหน้ารีวิวใน Hub (dev mode) เพื่อคัดเฟรมที่ใช้ได้
- ท่าที่ทำด้วย **transform ในโค้ด** (ไม่ต้องวาดหลายเฟรม): หายใจ (scale Y), กระโดด/ตก (สปริง), เอียงตามการลาก, หันซ้าย–ขวา (flip), เงา, สั่นตอนไข่ฟัก → ลดจำนวนภาพที่ต้อง gen ลงมาก

### 7.3 สัญญา Asset (Sprite Manifest)
```json
{
  "id": "blob_v1",
  "style": "2d-sprite",
  "stages": {
    "egg":      { "scale": 0.5, "pivot": [0.5, 0.0], "clips": { "idle": {"frames": 4, "fps": 6}, "hatch": {"frames": 6, "fps": 8} } },
    "hatchling":{ "scale": 0.6, "pivot": [0.5, 0.0], "clips": { "idle": {"frames": 4, "fps": 6}, "walk": {"frames": 6, "fps": 10}, "sleep": {"frames": 2, "fps": 2}, "eat": {"frames": 4, "fps": 8}, "happy": {"frames": 4, "fps": 8} } }
  },
  "fallbacks": { "*": "idle" },
  "props": { "food": "props/food", "note": "props/note", "camera": "props/camera" },
  "branches": { "chubby": "…", "playful": "…" }
}
```
- คลิปที่ขาดจะ fallback เป็น `idle` (หรือ transform ในโค้ด) เริ่มได้ด้วย 3–5 คลิปต่อขั้น
- ภาพหันทางเดียว (ขวา) แล้ว flip ด้วยโค้ดเพื่อลดจำนวนภาพ ถ้าสไตล์ไม่สมมาตรค่อยแยกซ้าย–ขวา
- ขนาดเฟรมมาตรฐาน 256×256 px @2x (แสดงจริง ~128 pt) พื้นหลังโปร่งใส PNG

### 7.4 รายการ asset ที่ต้องใช้ (ขั้นต่ำเพื่อเล่นได้)
| กลุ่ม | รายการ | จำนวนคร่าว ๆ |
|---|---|---|
| ไข่ | idle, สั่น, แตก | 3 คลิป ~12 เฟรม |
| สัตว์เลี้ยง × 4 ขั้น (Hatchling→Adult) | idle, walk, sleep, eat, happy | 5 คลิป × 4 เฟรมเฉลี่ย × 4 ขั้น ≈ 80 เฟรม |
| อาหาร/ของเล่น | 6–8 ไอคอน | 8 ภาพ |
| Prop | โน้ต, กล้อง, ไฟล์ที่คาบ, bubble | ~6 ภาพ |
| UI icons | เหรียญ, quest, vault, playlist ฯลฯ | ~10 ภาพ |

---

## 8. Feature Modules

### 8.1 Reminders
- Scheduler ของเราเองเป็นแหล่งความจริง (SwiftData) + `UNUserNotificationCenter` เป็นสำรองตอนแอปไม่ทำงาน
- รองรับ: ครั้งเดียว, ซ้ำ (รายวัน/สัปดาห์/ทุก N นาที), snooze, parse ภาษาธรรมชาติง่าย ๆ ("อีก 20 นาที", "พรุ่งนี้ 9 โมง") ด้วย `NSDataDetector`
- ตอนเด้ง สัตว์เลี้ยงเดินมาแสดง bubble + เสียง; เตือนซ้ำถ้าไม่กดรับ; เปิดแอปใหม่แล้วเตือนที่พลาดไป

### 8.2 File Vault ("ฝากไฟล์")
- ลากไฟล์/โฟลเดอร์/ข้อความ/ลิงก์มาวางที่สัตว์เลี้ยง → สัตว์ "คาบ" ไว้ + เก็บเข้า vault
- โหมดต่อรายการ: **Reference** (security-scoped bookmark ไม่ก็อปปี้ ชี้ไฟล์เดิม ถ้าไฟล์หาย แสดงสถานะ "หาย") หรือ **Copy** (เก็บใน `~/Library/Application Support/Hey/Vault/` ตั้งค่า default ได้)
- ปลายทาง: ลากออกจากสัตว์เลี้ยงกลับไปที่ Finder/แอปอื่น, ค้นหา/แท็ก/ปักหมุดใน Hub, ลบแบบ auto-expire (เช่น 7 วัน) เลือกได้
- ใช้ `NSDraggingDestination` ที่ PetWindow (ต้องมี drop zone รอบตัวสัตว์ตอนมีการลากเข้ามา — ตรวจด้วย `draggingEntered`)

### 8.3 Capture (รูป/วิดีโอ)
| โหมด | API | สิทธิ์ |
|---|---|---|
| ภาพหน้าจอ (เต็ม/หน้าต่าง/พื้นที่) | `SCScreenshotManager` | Screen Recording |
| วิดีโอหน้าจอ (+เสียงระบบ/ไมค์) | `SCRecordingOutput` | Screen Recording, Mic |
| ภาพ/วิดีโอจากกล้อง | `AVCapturePhotoOutput` / `AVCaptureMovieFileOutput` | Camera, Mic |

- ไฟล์เก็บใน `~/Movies/Hey/` และ `~/Pictures/Hey/`, ลงฐานข้อมูล `MediaItem`, มี gallery ใน Hub
- ระหว่างอัด สัตว์เลี้ยงทำท่าถือกล้อง + ไฟ indicator, **ซ่อนตัวเองจากภาพที่อัด** (exclude window ของแอปผ่าน `SCContentFilter(excludingWindows:)`)
- มี timer ถ่ายภาพ, hotkey เริ่ม/หยุดอัด

### 8.4 Music / YouTube Playlist
- เก็บ **ลิงก์ + metadata** (oEmbed: ชื่อ, ช่อง, thumbnail) ใน `PlaylistTrack`
- เล่นผ่าน `WKWebView` ซ่อนที่โหลด YouTube IFrame Player API; ควบคุมด้วย JS bridge (play/pause/next/seek/volume) รับ state กลับด้วย `postMessage`
- ผูก `MPNowPlayingInfoCenter` + `MPRemoteCommandCenter` เพื่อใช้ปุ่มมีเดียของแป้นพิมพ์/ศูนย์ควบคุมได้
- **ข้อจำกัด:** ต้องออนไลน์, มีโฆษณา, บางวิดีโอห้าม embed, WebView ต้องไม่ถูก suspend (ใช้ `NSProcessInfo.beginActivity`)
- **การโหลดเสียงลงเครื่อง (เช่น yt-dlp):** ขัด ToS ของ YouTube — เนื่องจากใช้ส่วนตัวจึงเป็นความเสี่ยงของคุณเอง **ไม่แนะนำให้ใส่ในแกนหลัก** หากต้องการ ให้เป็น plugin ภายนอกแยกไว้ ไม่ผูกกับระบบ
- รองรับไฟล์เพลงในเครื่อง (`AVPlayer`) ใน playlist เดียวกัน
- สัตว์เลี้ยงเต้นตามจังหวะแบบง่าย (ปรับ animation speed ตาม play state; ไม่ต้องวิเคราะห์เสียงจริง)

### 8.5 Pomodoro / Focus
- 25/5 ปรับได้, สัตว์เลี้ยงนั่งทำงานด้วย, จบรอบได้ XP, เชื่อมกับ quest และเตือนพัก

### 8.6 Sticky Notes
- โน้ตสั้นแปะข้างสัตว์เลี้ยง/ขอบจอ, เก็บ Markdown เบา ๆ, ตั้งเตือนจากโน้ตได้

---

## 9. ประเมิน Feature อื่น ๆ (ที่คุณให้ช่วยประเมิน)

คะแนน: คุ้มค่า = ประโยชน์ต่อเรา เทียบกับแรงที่ต้องทำ (★ มาก = ควรทำ)

| Feature | ความยาก | คุ้มค่า | คำแนะนำ |
|---|---|---|---|
| Pomodoro / โฟกัส | ง่าย | ★★★★★ | ทำเลย เข้ากับเกมที่สุด |
| Sticky notes | ง่าย | ★★★★ | ทำ |
| เตือนพัก/ดื่มน้ำ/ยืดเส้น | ง่าย | ★★★★ | เป็น template ของ reminders |
| เดินบนขอบหน้าต่างอื่น | กลาง | ★★★★ | wow factor สูง bounds ไม่ต้องขอสิทธิ์ |
| ปฏิกิริยาตามการใช้งาน (idle, เวลา, แบต) | ง่าย–กลาง | ★★★★ | ทำให้ดูมีชีวิต |
| Clipboard history | กลาง | ★★★ | เสี่ยงข้อมูลลับ ต้องมี ignore list + ไม่เก็บถาวร |
| มินิเกม (จับลูกบอล, จำท่า) | กลาง | ★★★ | แหล่งเหรียญ ทำหลังแกนเสร็จ |
| Quick launcher (เปิดแอป/ลิงก์โปรด) | ง่าย | ★★★ | สัตว์เลี้ยงเป็น dock ย่อย |
| Achievements / collection | ง่าย | ★★★ | ทำทีหลัง |
| Shortcuts / AppleScript hook | ง่าย | ★★★ | เปิดให้สั่ง Hey จาก Shortcuts ได้ (App Intents) |
| สภาพอากาศ/ปฏิทิน (EventKit) | กลาง | ★★ | สัตว์เลี้ยงบอกนัดถัดไป — ขอสิทธิ์ปฏิทิน |
| Focus mode ผูกกับ macOS Focus | กลาง | ★★ | ซ่อน/เงียบตาม Focus |
| หลายสัตว์เลี้ยง | กลาง | ★★ | โครงสร้างข้อมูลรองรับไว้แต่ UI ทำทีหลัง |
| Sync iCloud / iPhone widget | ยาก | ★★ | ตอนหลัง ถ้าต้องการ |
| AI คุยกับสัตว์เลี้ยง | กลาง | ★ | ไม่จำเป็น ต้นทุน+privacy ไว้ท้ายสุด |

---

## 10. Data Model (SwiftData)

| Entity | ฟิลด์หลัก |
|---|---|
| `Pet` | id, name, speciesId, stage, branch, xp, hunger, mood, energy, bond, favoriteFoodId, bornAt, lastTickAt, position(screenId,x,y) |
| `ItemDef` / `InventoryEntry` | kind(food/toy/deco/skin), effects, price / itemId, qty |
| `Quest` | date, type, target, progress, rewardCoin, rewardXP, doneAt |
| `StreakState` | current, best, lastActiveDate |
| `Wallet` | coins |
| `Reminder` | text, fireAt, repeatRule, snoozedUntil, doneAt, sourceNoteId? |
| `VaultItem` | name, kind, mode(ref/copy), bookmarkData / storedPath, tags, pinned, expiresAt, addedAt |
| `MediaItem` | kind(photo/video/screen), path, createdAt, duration |
| `Playlist` / `PlaylistTrack` | name / source(youtube/file), externalId|path, title, artist, thumbnailURL, order |
| `Note` | text, color, position, pinned |
| `GestureBinding` | gesture, action, enabled, params |
| `Setting` | key, value (หรือใช้ `@AppStorage` สำหรับค่าเล็ก ๆ) |
| `EventLog` | ts, type, payload (สำหรับ quest/debug, ตัดทิ้งเกิน 30 วัน) |

Static content (อาหาร, quest, balance, model manifest) เป็น JSON ใน bundle ไม่เข้า DB

---

## 11. สิทธิ์ (TCC) และการ Sign

| สิทธิ์ | ใช้เมื่อ | ขอเมื่อ |
|---|---|---|
| Notifications | Reminders | ตั้งเตือนครั้งแรก |
| Camera | ถ่ายรูป/วิดีโอจากกล้อง | ถ่ายครั้งแรก |
| Microphone | อัดวิดีโอ+เสียง | อัดครั้งแรก |
| Screen Recording | แคปจอ | แคปครั้งแรก |
| Accessibility | (ไม่บังคับ) hotkey/อ่านสถานะบางอย่าง | หลีกเลี่ยงถ้าทำได้ |
| Calendars | (ทางเลือก) | ถ้าเปิดฟีเจอร์ |
| Files (security-scoped) | Vault แบบ reference | อัตโนมัติจากการ drag-drop |

`PermissionCenter` เป็นจุดเดียวที่ตรวจ/ขอสิทธิ์ แสดงสถานะใน Hub และพาไป System Settings ถ้าถูกปฏิเสธ

**ข้อสำคัญสำหรับ dev:** macOS ผูกสิทธิ์กับ code signature — ถ้า build แล้ว sign แบบ ad-hoc ทุกครั้ง สิทธิ์จะถูกถามซ้ำ/หลุด ให้ใช้ **Apple Development certificate** คงที่ (Personal Team ฟรีได้) และตั้ง Hardened Runtime + entitlements `com.apple.security.device.camera`, `…audio-input` ปิด App Sandbox (ใช้ส่วนตัว)

---

## 12. CPU / Battery Analysis

> ตัวเลขด้านล่างเป็น **ค่าประมาณจากประสบการณ์กับงานลักษณะเดียวกันบน Apple Silicon ยังไม่ได้วัดจริง** ใช้เป็นงบประมาณเป้าหมาย (budget) แล้วยืนยันด้วยการวัดในแต่ละ milestone (12.5) ส่วน "Watt" คือกำลังไฟที่แอปเพิ่มเข้าไปเหนือระบบเปล่า ๆ

### 12.1 ใครกินทรัพยากรบ้าง (เรียงจากหนักไปเบา)

| แหล่งใช้ทรัพยากร | CPU | GPU/ANE | ประมาณ Watt เพิ่ม | สาเหตุหลัก | ความเสี่ยง |
|---|---|---|---|---|---|
| อัดวิดีโอหน้าจอ | กลาง | Media Engine | 2–4 W | encode H.264/HEVC | ใช้ชั่วคราวเท่านั้น ยอมรับได้ |
| YouTube ใน WKWebView | 2–5% | Video decode | 1–2 W | WebView ยังถอดรหัสวิดีโอแม้ซ่อนอยู่ | **สูง ถ้าเล่นยาว ๆ** |
| 2D sprite ตอนสัตว์เคลื่อนไหว | 1–2% | GPU | 0.1–0.4 W | 10–30 fps + หน้าต่างโปร่งใส (compositing) | ต่ำ–กลาง |
| 2D sprite ตอน idle นิ่ง | <1% | GPU | 0.02–0.1 W | 4–10 fps / หยุด | ต่ำ |
| โพลล์ตำแหน่งหน้าต่าง (เดินบนขอบ) | <0.5% | – | ~0.05 W | `CGWindowListCopyWindowInfo` 4 Hz | ต่ำ แต่ปลุก CPU ถี่ |
| Timer ของ domain (tick, scheduler) | <0.2% | – | ~0.02 W | wake-up ถี่ทำให้ CPU ไม่หลับลึก | **แอบสะสม ถ้ามี timer กระจัดกระจาย** |
| Reminders / Vault / Notes | ~0 | – | ~0 | ทำงานตามเหตุการณ์ | ไม่มีนัยสำคัญ |

**ข้อสังเกต:** ในงานแบบ "แอปเล็กรันตลอด" ตัวทำลายแบตจริง ๆ มักไม่ใช่ CPU % แต่คือ (1) จำนวน **wake-ups ต่อวินาที** ที่ไม่ให้ CPU หลับลึก และ (2) **GPU/compositing ของหน้าต่างโปร่งใสขนาดเต็มจอ** ที่ต้องผสมทุกเฟรมแม้ไม่มีอะไรขยับ

### 12.2 งบประมาณเป้าหมาย (Budget)

| สถานการณ์ | CPU เฉลี่ย | RAM | GPU | พลังงานเพิ่ม | อายุแบตที่หายไป (โน้ตบุ๊กใช้ ~8 W โดยรวม) |
|---|---|---|---|---|---|
| **Idle** (นั่ง/นอน, ไม่มีฟีเจอร์เปิด) | < 1% | < 120 MB | 10 fps | < 0.2 W | ~2–3% |
| **Active** (เดิน/เล่น/ลากมาก) | < 4% | < 150 MB | 30 fps | 0.3–0.8 W | ~5–10% |
| + เล่นเพลง YouTube | +2–5% | +80 MB | + decode | +1–2 W | ~12–25% |
| อัดจอ | ตามระบบ | | | +2–4 W | ชั่วคราว |

เป้าใช้งานปกติ (Idle + Active สลับกัน, ไม่เล่น YouTube): **เพิ่มการกินแบต ≤ 3–5%** ของอายุแบตเดิม ซึ่งคนทั่วไปแทบไม่รู้สึก
เมื่อเสียบไฟ AC ใช้งบประมาณแบบหลวมขึ้นได้ (ข้อ 12.3)

### 12.3 นโยบายพลังงานแบบปรับตัว (Power Policy)

มีโมดูลเดียว `PowerPolicy` ที่อ่านสถานะระบบแล้วประกาศ **ระดับ (tier)** ให้ทุกระบบฟัง ไม่ให้แต่ละระบบตัดสินใจเอง

| Tier | เงื่อนไข | พฤติกรรม |
|---|---|---|
| **Full** | เสียบ AC, ไม่ใช่ Low Power | 30 fps active, ทุกฟีเจอร์ |
| **Balanced** (default บนแบต) | ใช้แบต > 30% | 24 fps active, 8 fps idle |
| **Saver** | แบต ≤ 30% หรือ Low Power Mode หรือ `thermalState ≥ .fair` | 15 fps active, 4 fps idle, โพลล์หน้าต่างอื่นปิด (ไม่เดินบนขอบ) |
| **Dormant** | จอดับ / ล็อก / เต็มจอ / แชร์จอ / ผู้ใช้ไม่อยู่ > N นาที / โหมดเงียบ | หยุด render (0 fps), เหลือแค่ scheduler (เตือน) |

อ่านสัญญาณจาก: `ProcessInfo.isLowPowerModeEnabled`, `.thermalState`, `IOPSCopyPowerSourcesInfo` (แบต/AC), `NSWorkspace` notifications (sleep/wake, screens sleep, active space), `CGEventSource.secondsSinceLastEventType` (ผู้ใช้ idle)

### 12.4 มาตรการลดการใช้ทรัพยากรตามส่วน

**Rendering / หน้าต่าง**
- **Render-on-demand:** ถ้าสัตว์ไม่ขยับ (sleep/sit/นิ่ง) หยุด display link แล้ววาดใหม่เมื่อมี animation event เท่านั้น แทนที่จะวาด 10 fps ตลอด
- ใช้หน้าต่างเล็กขนาดเท่าตัวสัตว์ (ตัดสินใจใน S1) ดีกว่าหน้าต่างเต็มจอโปร่งใส เพราะลดพื้นที่ compositing มหาศาล
- Model เบา: จำกัดจำนวนรูปสามเหลี่ยม (< 20k), texture ≤ 1024², ไม่ใช้ shadow แบบ real-time (ใช้ blob shadow), ไม่มี post-processing
- ใช้ `preferredFramesPerSecond` ตาม tier และสถานะ FSM

**Timers / wake-ups**
- ใช้ **นาฬิกาเดียว** (`DispatchSourceTimer` พร้อม `leeway` กว้าง เช่น 1–2 วิ) แล้วให้ระบบย่อยสมัครรับ tick แทนการมี `Timer` กระจัดกระจาย
- งานที่ไม่ละเอียดเวลา (ลด stats, ตรวจ quest) รวมเป็น batch ทุก 60 วินาที ไม่ใช่ทุกเฟรม
- Reminder ใช้ `fireAt` ล่วงหน้าตั้ง timer เดียวไปยังเหตุการณ์ถัดไป ไม่ใช่โพลล์
- โพลล์ตำแหน่งหน้าต่าง (4 Hz) **เปิดเฉพาะตอนสัตว์เดินอยู่บนหน้าต่าง** ปิดที่อื่น


**Music (YouTube)**
- ถ้าเป็นไปได้ใช้ iframe ขนาดเล็กสุด + ขอ quality ต่ำ (ใช้ได้ไม่เสมอ YouTube อาจไม่ฟัง) เพราะเราต้องการแค่เสียง
- อย่ารอให้ผู้ใช้เล่นยาว: แจ้งใน Hub ว่า "เล่นจาก YouTube กินแบตกว่าไฟล์ในเครื่อง ~เท่าไร" และ**แนะนำไฟล์ในเครื่อง** (ใช้ AVPlayer แค่ decode เสียง ~0.1–0.3 W) เมื่อใช้แบต
- เมื่อ tier = Saver และกำลังเล่น YouTube → แสดง toast เสนอสลับ/หยุด ไม่ตัดเอง
- หยุด WebView ทั้งหมดเมื่อไม่ได้เล่น (ไม่เก็บ WebView ไว้ตัวเปล่า ๆ)

**Capture**
- สร้าง `SCStream` เมื่อเริ่มอัดเท่านั้น ปิดทันทีเมื่อเสร็จ; จำกัด fps วิดีโอที่ 30 (ค่าเริ่มต้น) และเสนอ 15 สำหรับสาธิตหน้าจอ
- ใช้ hardware encoder (HEVC) ผ่าน SCRecordingOutput อยู่แล้ว

**หน่วยความจำ**
- โหลด model ของขั้นปัจจุบันขั้นเดียว ปล่อยของขั้นอื่น/โหลดแอนิเมชันที่ไม่ได้ใช้แบบ lazy
- Thumbnail playlist/gallery ใช้ cache แบบ LRU จำกัดขนาด

### 12.5 แผนการวัดผล (ต้องทำจริง ไม่ใช่เชื่อประมาณ)

| เครื่องมือ | วัดอะไร | เมื่อไหร่ |
|---|---|---|
| Xcode **Energy Gauge** / Instruments **Energy Log** | impact เป็นระดับ Low/Med/High, overhead ต่อส่วน | ทุก milestone |
| Instruments **Time Profiler** | hotspot CPU | เมื่อ CPU เกินงบ |
| Instruments **Metal System Trace / Core Animation** | GPU time, compositing, frame pacing | M1 และเมื่อเปลี่ยน rendering |
| Instruments **System Trace** (wake-ups) | จำนวน wake-up/วินาที, timer coalescing | M2, M4 |
| `sudo powermetrics --samplers cpu_power,gpu_power,ane_power -i 5000` | W จริงของ CPU/GPU/ANE ขณะแอปทำงาน เทียบ baseline | ทุก milestone ที่เพิ่มฟีเจอร์หนัก |
| `pmset -g batt` / ทดสอบแบต 1 ชม. | การลดของแบตจริงเทียบกับ baseline (ไม่เปิดแอป) | ก่อนปิดแต่ละ milestone |
| Activity Monitor → Energy tab ("12 hr Power") | ค่าเฉลี่ยสะสม | ตรวจรายวันตอนใช้งานจริง |

**วิธีทดสอบมาตรฐาน:** แต่ละสถานการณ์ในตาราง 12.2 วัด 10 นาที ที่ความสว่างจอคงที่ ปิดแอปอื่น เปรียบเทียบกับ baseline (ไม่เปิด Hey) บันทึกผลลง `docs/perf-log.md` และตั้ง **regression gate**: ถ้าเกินงบ >25% ต้องแก้ก่อนปิด milestone

### 12.6 ข้อสรุป

1. **ส่วนที่กินแบตจริงคือ YouTube (และอัดจอตอนใช้)** — เล่นเพลงควรแนะนำไฟล์ในเครื่องเมื่อใช้แบต ส่วน gesture ไม่ใช้กล้องจึงแทบไม่มีต้นทุน
2. **การใช้งานหลัก (สัตว์เลี้ยง + เตือน + vault) เบามาก** ถ้าคุม FPS, render-on-demand และ timer ให้ดี คาดว่า <1% CPU ตอน idle
3. **จุดเสี่ยงที่ต้องพิสูจน์เร็วที่สุด** คือต้นทุน compositing ของหน้าต่างโปร่งใส + SpriteKit (เติมเข้า spike S1 ให้วัด W ด้วย `powermetrics` ไม่ใช่แค่ดูว่า "แสดงได้")
4. ควรสร้าง `PowerPolicy` ตั้งแต่ M1 เพราะทุกระบบจะอ้างอิง ถ้าเพิ่มทีหลังต้องรื้อ

---

## 13. โครงสร้างโปรเจกต์

```
Hey/
├─ Hey.xcodeproj
├─ App/                    # HeyApp, AppDelegate, MenuBarExtra
├─ Domain/                 # Swift Package: PetEngine, Stats, Growth, Behavior, Quest, Economy (ไม่ import UIKit/AppKit)
├─ Input/                  # InputEventBus, GestureRecognizer, ActionMapper, Hotkeys
├─ Platform/               # CameraManager, ScreenService, Scheduler, PermissionCenter, Store
├─ Features/               # Reminders, Vault, Capture, Music, Pomodoro, Notes
├─ Presentation/           # PetWindow, PetScene (SpriteKit), Hub (SwiftUI), Overlays
├─ Resources/              # balance.json, quests.json, items.json, Models/<id>/manifest.json
├─ Tests/
└─ docs/DESIGN.md
```

---

## 14. Roadmap

### Spikes (ทำก่อนเริ่มจริง ใช้เวลาอย่างละ ~1–2 วัน)
| # | ทดลอง | ผ่านเมื่อ |
|---|---|---|
| S1 | SpriteKit (`SKView`) บน `NSPanel` โปร่งใส + click-through ตามพิกเซล + drag-drop เข้า | เห็นโมเดลลอยบนเดสก์ท็อปจริง, คลิกทะลุส่วนว่างได้, ลากไฟล์มาวางได้, **idle < 0.2 W และ active < 0.8 W (วัดด้วย powermetrics)** |
| S2 | Gesture recognizer บน NSEvent: ลูบ/ลาก/ดีด/เขย่า + scroll/magnify บน trackpad | แยกท่าได้ถูกต้อง ≥ 95% ในการทดลองด้วยมือตัวเอง, ไม่ชนกับคลิก/ลาก |
| S3 | YouTube IFrame ใน WKWebView ซ่อน + MediaRemote | เล่นเมื่อหน้าต่างซ่อน, ปุ่มมีเดียทำงาน |
| S4 | ScreenCaptureKit exclude หน้าต่างตัวเอง + `SCRecordingOutput` | อัดได้โดยไม่เห็นสัตว์เลี้ยง |

ถ้า S1 ไม่ผ่าน → สลับไป SceneKit/Metal ก่อนค่อยทำอย่างอื่น

### Milestones
| M | ขอบเขต | ผลลัพธ์ |
|---|---|---|
| M1 | PetWindow + placeholder model + FSM + pointer gestures (ลูบ/อุ้ม/ดีด) + `PowerPolicy` + นาฬิกากลาง | สัตว์เลี้ยงเดินได้บนจอ ภายใต้งบพลังงาน |
| M2 | Domain เต็ม: stats, ไข่/ฟัก, ให้อาหาร, XP, วิวัฒนาการ, SwiftData, offline catch-up + unit tests | เลี้ยงโตได้ |
| M3 | Quest + streak + economy + ร้านค้า + Hub | ลูปรายวันครบ |
| M4 | Reminders + Pomodoro + Notes | ใช้งานจริงประจำวัน |
| M5 | File Vault | ฝากไฟล์ได้ |
| M6 | Music/YouTube playlist | |
| M7 | Capture รูป/วิดีโอ | |
| M8 | Trackpad gestures (scroll/magnify/rotate) + hot corner + กำหนด mapping เอง | |
| M9 | Polish: เดินบนหน้าต่าง, ปฏิกิริยาตามบริบท, achievements, มินิเกม, model จริง | |

---

## 15. ความเสี่ยง

| ความเสี่ยง | ผล | แผนรับมือ |
|---|---|---|
| SpriteKit โปร่งใส/click-through ไม่เสถียร | ต่ำ–กลาง | spike S1 |
| ภาพจาก AI ไม่สม่ำเสมอระหว่างเฟรม | กลาง | character sheet อ้างอิง, ใช้ transform ในโค้ดแทนเฟรม, คัดเฟรมใน dev mode |
| สิทธิ์ TCC หลุดตอน build | กลาง | ใช้ cert คงที่ |
| YouTube เปลี่ยนพฤติกรรม/บล็อก embed | กลาง | รองรับไฟล์ในเครื่องควบคู่ |
| ท่าบนเมาส์/trackpad ชนกัน (คลิก vs ลาก vs ลูบ) | ต่ำ–กลาง | กฎลำดับความสำคัญ + พารามิเตอร์ใน gestures.json |
| สัตว์เลี้ยงรบกวนงาน | กลาง | โหมดเงียบ, ซ่อนเมื่อเต็มจอ/แชร์จอ, ปรับขนาด |
| Asset ไม่ตรงสัญญา | ต่ำ | manifest + fallback clip |
| Scope บวม | สูง | ทำตาม milestone, Feature เป็นโมดูลปิด/เปิดได้ |

---

## 16. คำถามที่ยังเปิดอยู่

1. สัตว์เลี้ยงเป็นสายพันธุ์ไหน/สไตล์ภาพ (pixel art / วาดเรียบ / cute chibi) — ตอนนี้ใช้ blob-creature สีพาสเทลเป็น placeholder
2. ต้องการ Dock icon ไหม หรืออยู่แค่ menu bar (ค่าเริ่มต้นในเอกสาร: ไม่มี Dock icon)
3. ภาษา UI: ไทยอย่างเดียว หรือไทย/อังกฤษ
4. อยากให้ผูก iPhone/iCloud ภายหลังหรือไม่ (มีผลต่อ SwiftData config → ถ้าอาจใช้ CloudKit ควรวาง schema ให้เข้ากันได้ตั้งแต่ต้น)
