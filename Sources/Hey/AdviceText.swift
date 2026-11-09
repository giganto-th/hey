import HeyDomain

extension Advice {
    /// The full sentence for the machine page.
    var message: String {
        switch kind {
        case .cpuBusy(let name?, _): tr("CPU ทำงานหนักต่อเนื่อง ส่วนใหญ่มาจาก {0} ลองพักหรือปิดงานนั้น", name)
        case .cpuBusy(nil, _): tr("CPU ทำงานหนักต่อเนื่อง ลองปิดแอปที่ไม่ได้ใช้ หรือรอให้งานที่ทำอยู่เสร็จก่อน")
        case .memoryPressure(let name?, let bytes): tr("หน่วยความจำเริ่มตึง {0} ใช้อยู่ {1} ลองปิดแอปนี้หรือแท็บที่ไม่ได้ใช้", name, ByteText.size(bytes))
        case .memoryPressure(nil, _): tr("หน่วยความจำเริ่มตึง ลองปิดแอปและแท็บเบราว์เซอร์ที่ไม่ได้ใช้")
        case .swapHeavy(let bytes): tr("ใช้ swap ไปแล้ว {0} เครื่องอาจช้าลง รีสตาร์ตเครื่องจะช่วยล้างได้", ByteText.size(bytes))
        case .diskLow(let free, let reclaimable):
            reclaimable > 0 ? tr("พื้นที่ดิสก์เหลือ {0} เคลียร์ได้ราว {1} จากรายการด้านล่าง", ByteText.size(free), ByteText.size(reclaimable))
                            : tr("พื้นที่ดิสก์เหลือ {0} สแกนหาที่ที่เคลียร์ได้", ByteText.size(free))
        case .hot(let c): tr("เครื่องร้อน {0}°C พักงานหนัก ย้ายไปที่ระบายอากาศดี หรือปิดแอปที่ใช้ CPU มาก", Int(c.rounded()))
        case .throttled: tr("ระบบกำลังลดความเร็วเพราะความร้อน พักงานหนักสักครู่")
        case .allGood: tr("ทุกอย่างปกติ ไม่มีอะไรต้องจัดการ")
        }
    }

    /// A short line for the pet to say.
    var spoken: String {
        switch kind {
        case .hot(let c): tr("เครื่องร้อน {0}°C แล้วนะ พักงานหนักหน่อย", Int(c.rounded()))
        case .throttled: tr("เครื่องร้อนจนต้องลดความเร็ว พักหน่อยนะ")
        case .diskLow(let free, _): tr("ดิสก์เหลือแค่ {0} แล้วนะ ไปดูที่เคลียร์ได้ใน Hub", ByteText.size(free))
        case .memoryPressure: tr("หน่วยความจำตึงมากแล้ว ลองปิดแอปที่ไม่ได้ใช้")
        default: message
        }
    }

    var symbol: String {
        switch area {
        case .heat: "thermometer.high"
        case .disk: "internaldrive"
        case .memory: "memorychip"
        case .cpu: "cpu"
        }
    }
}
