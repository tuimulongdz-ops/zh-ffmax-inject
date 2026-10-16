

import Foundation

class Injector {
    static let shared = Injector()

    func inject(aimbot: Bool, headLock: Bool, trigger: Bool,
                antiBan: Bool, antiReport: Bool, antiAFK: Bool, antiKick: Bool,
                speed: Bool, wallhack: Bool, fov: Double, smooth: Double) {

        guard let luaPath = Bundle.main.path(forResource: "aimbot", ofType: "lua") else { return }

        // Ghi config vao file tam de script doc
        let cfg = """
        aimbot=\(aimbot)
        head_lock=\(headLock)
        trigger=\(trigger)
        anti_ban=\(antiBan)
        anti_report=\(antiReport)
        anti_afk=\(antiAFK)
        anti_kick=\(antiKick)
        speed=\(speed)
        wallhack=\(wallhack)
        fov=\(fov)
        smooth=\(smooth)
        """
        let tmp = NSTemporaryDirectory() + "zh_config.ini"
        try? cfg.write(toFile: tmp, atomically: true, encoding: .utf8)

        DispatchQueue.global(qos: .background).async {
            if aimbot || antiBan {
                inject_lua(luaPath)
            } else {
                stop_lua()
            }
        }
    }
}

@_silgen_name("inject_lua")
func inject_lua(_ path: String)

@_silgen_name("stop_lua")
func stop_lua()
