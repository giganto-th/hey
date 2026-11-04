# เซ็นและ notarize Hey! โดยไม่ใช่ Account Holder

Apple อนุญาตให้ **Account Holder** เท่านั้นสร้างใบรับรอง Developer ID แต่ไม่จำเป็นต้องส่งกุญแจส่วนตัวให้ใคร
ใช้วิธี CSR: กุญแจส่วนตัวอยู่ในเครื่องของผู้ที่จะเซ็นแอป Account Holder แค่ออกใบรับรองให้

## ฝั่งคนที่จะเซ็นแอป (เครื่องที่บิลด์ Hey!)
1. เปิด Keychain Access › เมนู Keychain Access › Certificate Assistant › **Request a Certificate From a Certificate Authority…**
2. ใส่อีเมล ชื่อ (Common Name) เลือก **Saved to disk** (ไม่ต้องเลือก Emailed to the CA) ได้ไฟล์ `CertificateSigningRequest.certSigningRequest`
3. ส่งไฟล์ `.certSigningRequest` นี้ให้ Account Holder (ไม่มีความลับในไฟล์นี้ ส่งทางอีเมล/แชตได้)

## ฝั่ง Account Holder
1. เข้า developer.apple.com › Account › Certificates, IDs & Profiles › Certificates › **+**
2. เลือก **Developer ID Application** (ไม่ใช่ Installer) › Continue
3. เลือก Profile Type **G2 Sub-CA (Xcode 11.4.1 or later)** › Continue
4. อัปโหลดไฟล์ `.certSigningRequest` ที่ได้รับ › Continue › **Download** ได้ไฟล์ `developerID_application.cer`
5. ส่งไฟล์ `.cer` กลับ (ไฟล์นี้เป็นสาธารณะ ไม่มีความลับ)

## ฝั่งคนที่จะเซ็นแอป (ต่อ)
1. ดับเบิลคลิกไฟล์ `.cer` ให้เข้า Keychain (login) มันจะจับคู่กับกุญแจส่วนตัวที่สร้างในขั้นตอนแรกเอง
2. ตรวจว่าพร้อมใช้: `security find-identity -v -p codesigning` ต้องเห็น `Developer ID Application: ... (TEAMID)`
3. สร้างรหัสผ่านเฉพาะแอป (appleid.apple.com › Sign-In and Security › App-Specific Passwords) แล้วเก็บเข้า Keychain:
   `xcrun notarytool store-credentials hey-notary --apple-id <Apple ID> --team-id <TEAMID> --password <รหัสผ่านเฉพาะแอป>`
   (Apple ID กับ Team ID ต้องเป็นของ Account Holder ถ้า notarize ในนามบัญชีนั้น: ให้ Account Holder สร้างรหัสผ่านเฉพาะแอปส่งให้ หรือเพิ่มคุณเป็น Admin แล้วใช้ Apple ID ของคุณเองได้ถ้าทีมอนุญาต)
4. ปล่อยเวอร์ชัน:
   `HEY_SIGN_IDENTITY="Developer ID Application: ชื่อ (TEAMID)" HEY_NOTARY_PROFILE=hey-notary scripts/release-signed.sh`

ถ้า notarize ด้วย Apple ID ของคุณเอง ให้ลองก่อนว่า `notarytool` ยอมรับ ถ้าไม่ได้ ให้ Account Holder เป็นคนรันขั้นตอน notarize (ข้อ 3 ถึง 4) เอง
