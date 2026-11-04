# Hei Hei motion concept — image provenance

เครื่องมือ: built-in `image_gen.imagegen` ไม่ใช้ CLI fallback
วันที่: 3 พฤศจิกายน 2026
Reference: `Resources/Sprites/heihei/adult_idle.png` เปิดตรวจภาพก่อนสร้าง
ต้นฉบับ: `heihei-motion-concept-v1.png`, 1774×887 RGBA
Preview: `heihei-motion-preview-v1.webp` เข้ารหัสด้วย cwebp quality 82 คงขนาดและ alpha; ไม่ retouch/crop ภาพ
การใช้งาน: concept สำหรับตรวจบุคลิกและ UX ไม่ใช่ final animation atlas

## Exact generation prompt

```text
Use case: stylized-concept. Create a production-design MOTION POSE CONTACT SHEET for Hey!, a macOS 2D desktop pet. Subject is explicitly Hei Hei the rooster from Disney's animated Moana, as requested by the owner. Use the attached existing sprite only as a style continuity reference, but make the identity MORE faithful to animated Hei Hei: tall skinny articulated golden ochre neck, huge bulging independently wandering white eyes with tiny black pupils, red irregular floppy comb and red wattles, long pointed yellow-orange beak, brown compact torso, scraggly dark teal-green arching tail, scrawny yellow legs, bewildered clueless comic demeanor. Do not turn him into a round generic chick. Clean expressive hand-drawn 2D animation key poses with dark warm outlines and restrained flat shading. Landscape sheet, EXACT uniform 4 columns by 2 rows, eight equal square cells, transparent background, no grid lines, labels, letters or watermarks. Every cell shows one full-body same adult rooster at same scale with the same feet baseline, margins 12%, all anatomy inside cell. Facing right or right three-quarter. TOP ROW left to right: 1 neutral puzzled standing; 2 goofy dance left step one foot up head tilted back wing spread; 3 goofy dance right step opposite foot up neck curved right; 4 dance downbeat squat head low wings flicking. BOTTOM ROW left to right: 5 preparing to peck, long neck arched head halfway down, beside a tiny light gray miniature keyboard; 6 beak touching a key on the same miniature keyboard, neck curved all the way down, feet planted; 7 head popped up startled after pecking, eyes looking in different directions, same keyboard; 8 sleepy standing eyes half closed neck tucked. Keep dance poses distinctly different and full body. Do not include props in the top row. Preserve transparent alpha.
```

## Observations

คอยาวและดวงตาใกล้ทิศทาง Hei Hei มากกว่าภาพเดิม แต่ตำแหน่งปาก เท้า ลำตัว และความสูงแปรตามช่อง การทำแอนิเมชันจริงต้องจัด anchor และวาด in-between ไม่อ้างว่าภาพชุดนี้ผ่าน production QA แล้ว ท่าลูบและรับอาหารในต้นแบบใช้การสื่อท่าหลักอย่างหยาบตามข้อจำกัดของ 8 poses; ให้ใช้ motion spec เป็น requirement สำหรับผลิตคลิปจริง
