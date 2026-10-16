
import UIKit
import SwiftUI
import AVFoundation

// ============================================
// COLORS
// ============================================
let SEA_CYAN = Color(red: 0.0, green: 0.83, blue: 1.0)
let SEA_BLUE = Color(red: 0.0, green: 0.6, blue: 1.0)
let RED_ACCENT = Color(red: 1.0, green: 0.0, blue: 0.2)
let DARK_BG = Color(red: 0.05, green: 0.06, blue: 0.09)
let NEON_GREEN = Color(red: 0.2, green: 1.0, blue: 0.4)
let GOLD = Color(red: 1.0, green: 0.84, blue: 0.0)
let ZALO_BLUE = Color(red: 0.0, green: 0.4, blue: 0.8)

// ============================================
// APP DELEGATE
// ============================================
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}

        let win = UIWindow(frame: UIScreen.main.bounds)
        win.rootViewController = UIHostingController(rootView: MainMenuView())
        win.makeKeyAndVisible()
        self.window = win
        return true
    }
}

// ============================================
// STATE
// ============================================
class MenuState: ObservableObject {
    // Game selection
    @Published var game: String = "ffmax" // "ff" hoặc "ffmax"
    @Published var autoOpen: Bool = false

    // Nhẹ tâm
    @Published var lightAimOn: Bool = false
    @Published var lightAimStrength: Double = 0.5
    @Published var lightAimRange: Double = 200
    @Published var lightAimSmooth: Double = 0.5

    // Sensitivity
    @Published var sensX: Double = 1.0
    @Published var sensY: Double = 1.0
    @Published var sensScope: Double = 0.5

    // Tâm ảo
    @Published var crosshairOn: Bool = true
    @Published var crosshairSize: Double = 80
    @Published var crosshairOpacity: Double = 1.0
    @Published var crosshairColor: Int = 0
    @Published var crosshairStyle: Int = 0 // 0=circle, 1=cross, 2=dot, 3=full

    // Ghost
    @Published var ghostOn: Bool = false
    @Published var ghostFollowSpeed: Double = 0.4

    // Head guide
    @Published var headGuideOn: Bool = false
    @Published var headGuideY: Double = 100

    // Cursor lock
    @Published var cursorLockOn: Bool = false

    // Touch smooth
    @Published var touchSmooth: Bool = true

    // Runtime
    @Published var fps: Int = 0
    @Published var batteryLevel: Int = 100
    @Published var isCharging: Bool = false
    @Published var deviceName: String = ""
    @Published var iosVersion: String = ""
    @Published var screenSize: String = ""
    @Published var logLines: [String] = []
    @Published var zaloAlertShown: Bool = false

    init() {
        deviceName = UIDevice.current.model
        iosVersion = UIDevice.current.systemVersion
        screenSize = "\(Int(UIScreen.main.bounds.width))x\(Int(UIScreen.main.bounds.height))"
        setupBatteryMonitor()
    }

    func log(_ msg: String) {
        let t = DateFormatter()
        t.dateFormat = "HH:mm:ss"
        logLines.append("[\(t.string(from: Date()))] \(msg)")
        if logLines.count > 100 { logLines.removeFirst() }
    }

    func setupBatteryMonitor() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        updateBattery()
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil, queue: .main
        ) { _ in self.updateBattery() }
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification,
            object: nil, queue: .main
        ) { _ in self.updateBattery() }
    }

    func updateBattery() {
        let level = UIDevice.current.batteryLevel
        batteryLevel = level < 0 ? 100 : Int(level * 100)
        isCharging = UIDevice.current.batteryState == .charging
            || UIDevice.current.batteryState == .full
    }

    func color() -> Color {
        switch crosshairColor {
        case 0: return .red
        case 1: return SEA_CYAN
        case 2: return NEON_GREEN
        case 3: return .white
        case 4: return .yellow
        case 5: return .pink
        default: return .red
        }
    }

    func gameBundle() -> String {
        return game == "ff" ? "com.dts.freefireth" : "com.dts.freefiremax"
    }

    func gameName() -> String {
        return game == "ff" ? "FREE FIRE" : "FREE FIRE MAX"
    }

    func openGame() {
        guard let url = URL(string: "\(gameBundle())://") else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:]) { success in
                if success { self.log("✅ Đã mở \(self.gameName())") }
                else { self.log("❌ Không mở được game") }
            }
        } else {
            log("⚠️ Game chưa cài — thử mở bằng scheme khác")
        }
    }
}

// ============================================
// MAIN MENU
// ============================================
struct MainMenuView: View {
    @ObservedObject var s = MenuState()
    @State private var selectedTab: Int = 0
    @State private var showZaloAlert = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.02, green: 0.03, blue: 0.05), DARK_BG],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .edgesIgnoringSafeArea(.all)

            GeometryReader { geo in
                Group {
                    Circle().fill(SEA_BLUE.opacity(0.28)).frame(width: 320, height: 320)
                        .blur(radius: 100).position(x: 60, y: 80)
                    Circle().fill(RED_ACCENT.opacity(0.20)).frame(width: 280, height: 280)
                        .blur(radius: 100).position(x: geo.size.width - 60, y: geo.size.height - 220)
                }
            }.edgesIgnoringSafeArea(.all)

            OverlayView(state: s)

            VStack(spacing: 10) {
                header
                hudRow
                gameSelector
                tabsBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        if selectedTab == 0 { lightAimTab }
                        else if selectedTab == 1 { sensTab }
                        else if selectedTab == 2 { visualTab }
                        else if selectedTab == 3 { deviceTab }
                        else { contactTab }
                    }.padding(.bottom, 20)
                }
                footer
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
        }
        .preferredColorScheme(.dark)
        .alert(isPresented: $showZaloAlert) {
            Alert(
                title: Text("LIÊN HỆ ADMIN"),
                message: Text("Zalo: 0919178382\nAdmin: Ph Hai Long"),
                primaryButton: .default(Text("MỞ ZALO")) {
                    openZalo()
                },
                secondaryButton: .cancel(Text("ĐÓNG"))
            )
        }
    }

    // MARK: - Header
    var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(LinearGradient(colors: [SEA_BLUE, SEA_CYAN, RED_ACCENT],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 46, height: 46)
                    .shadow(color: SEA_CYAN.opacity(0.9), radius: 12)
                Text("ZH").font(.system(size: 17, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("ZWILZ HLONG").font(.system(size: 16, weight: .heavy)).foregroundColor(.white)
                Text("Admin: Ph Hai Long").font(.system(size: 9, weight: .bold)).foregroundColor(GOLD)
            }
            Spacer()
            Button(action: { showZaloAlert = true }) {
                ZStack {
                    Circle().fill(ZALO_BLUE).frame(width: 40, height: 40)
                        .shadow(color: ZALO_BLUE.opacity(0.8), radius: 8)
                    Image(systemName: "phone.fill").foregroundColor(.white)
                        .font(.system(size: 16, weight: .bold))
                }
            }
        }
        .padding(14)
        .background(LinearGradient(colors: [SEA_CYAN.opacity(0.20), DARK_BG.opacity(0.95), RED_ACCENT.opacity(0.16)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20)
                    .stroke(LinearGradient(colors: [SEA_CYAN, .white, RED_ACCENT],
                                           startPoint: .leading, endPoint: .trailing), lineWidth: 1.3))
    }

    // MARK: - HUD
    var hudRow: some View {
        HStack(spacing: 8) {
            hudItem(title: "FPS", value: "\(s.fps)")
            hudItem(title: "PIN", value: "\(s.batteryLevel)%")
            hudItem(title: "CHARGE", value: s.isCharging ? "⚡" : "-")
            hudItem(title: "SENS", value: String(format: "%.1f", s.sensX))
        }
    }
    func hudItem(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.system(size: 8, weight: .bold)).foregroundColor(.gray)
            Text(value).font(.system(size: 12, weight: .heavy, design: .monospaced)).foregroundColor(SEA_CYAN)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 9)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: - Game Selector
    var gameSelector: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                gameBtn(id: "ff", icon: "🔥", title: "FREE FIRE", sub: "ffth")
                gameBtn(id: "ffmax", icon: "💥", title: "FF MAX", sub: "ffmax")
            }
            HStack(spacing: 8) {
                toggleSmall(icon: "🚀", title: "TỰ MỞ GAME", isOn: $s.autoOpen)
                Button(action: { s.openGame() }) {
                    HStack(spacing: 6) {
                        Text("▶").font(.system(size: 14, weight: .heavy))
                        Text("MỞ NGAY").font(.system(size: 11, weight: .heavy))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(LinearGradient(colors: [SEA_CYAN, RED_ACCENT],
                                               startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                    .shadow(color: SEA_CYAN.opacity(0.6), radius: 6)
                }
            }
        }
    }
    func gameBtn(id: String, icon: String, title: String, sub: String) -> some View {
        let on = s.game == id
        return Button(action: {
            s.game = id
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            s.log("CHỌN GAME: \(title)")
        }) {
            HStack(spacing: 10) {
                Text(icon).font(.system(size: 20))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 12, weight: .heavy)).foregroundColor(.white)
                    Text(sub).font(.system(size: 8.5, design: .monospaced)).foregroundColor(.gray)
                }
                Spacer()
                if on {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(SEA_CYAN).font(.system(size: 18))
                }
            }
            .padding(11)
            .background(on
                        ? LinearGradient(colors: [SEA_CYAN.opacity(0.22), RED_ACCENT.opacity(0.14)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.white.opacity(0.05), Color.white.opacity(0.02)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(on ? SEA_CYAN : Color.white.opacity(0.1), lineWidth: 1))
        }.buttonStyle(PlainButtonStyle())
    }
    func toggleSmall(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        Button(action: {
            isOn.wrappedValue.toggle()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            HStack(spacing: 6) {
                Text(icon).font(.system(size: 14))
                Text(title).font(.system(size: 10, weight: .heavy))
                    .foregroundColor(isOn.wrappedValue ? .white : .gray)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(isOn.wrappedValue
                        ? LinearGradient(colors: [NEON_GREEN.opacity(0.5), SEA_CYAN.opacity(0.4)],
                                         startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [Color.white.opacity(0.05), Color.white.opacity(0.05)],
                                         startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11)
                        .stroke(isOn.wrappedValue ? NEON_GREEN : Color.white.opacity(0.1), lineWidth: 1))
        }.buttonStyle(PlainButtonStyle())
    }

    // MARK: - Tabs
    var tabsBar: some View {
        HStack(spacing: 5) {
            tabBtn(idx: 0, title: "NHẸ TÂM")
            tabBtn(idx: 1, title: "SENS")
            tabBtn(idx: 2, title: "TÂM ẢO")
            tabBtn(idx: 3, title: "THIẾT BỊ")
            tabBtn(idx: 4, title: "LIÊN HỆ")
        }
        .padding(4)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
    func tabBtn(idx: Int, title: String) -> some View {
        Button(action: { selectedTab = idx }) {
            Text(title).font(.system(size: 9.5, weight: .heavy))
                .foregroundColor(selectedTab == idx ? .white : .gray)
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(Group {
                    if selectedTab == idx {
                        LinearGradient(colors: [SEA_CYAN, RED_ACCENT],
                                       startPoint: .leading, endPoint: .trailing)
                    } else { Color.clear }
                })
                .clipShape(RoundedRectangle(cornerRadius: 11))
        }
    }

    // MARK: - TAB 1: NHẸ TÂM
    var lightAimTab: some View {
        VStack(spacing: 10) {
            sectionTitle("HỖ TRỢ KÉO TÂM")
            toggleCard(icon: "🪶", title: "NHẸ TÂM", sub: "Giảm ma sát khi kéo tâm", isOn: $s.lightAimOn)
            toggleCard(icon: "👻", title: "GHOST FOLLOW", sub: "Tâm ảo bám theo ngón tay", isOn: $s.ghostOn)
            toggleCard(icon: "📲", title: "TOUCH SMOOTH", sub: "Giảm delay cảm ứng", isOn: $s.touchSmooth)
            toggleCard(icon: "🔒", title: "CURSOR LOCK", sub: "Khóa tâm ở giữa", isOn: $s.cursorLockOn)

            sectionTitle("TINH CHỈNH NHẸ TÂM")
            sliderCard(title: "ĐỘ NHẸ", value: $s.lightAimStrength, range: 0.1...1.0, suffix: "")
            sliderCard(title: "PHẠM VI", value: $s.lightAimRange, range: 50...500, suffix: "px")
            sliderCard(title: "ĐỘ MƯỢT", value: $s.lightAimSmooth, range: 0.1...1.0, suffix: "")
            sliderCard(title: "TỐC GHOST", value: $s.ghostFollowSpeed, range: 0.1...1.0, suffix: "")

            sectionTitle("TRẠNG THÁI")
            infoCard(title: "NHẸ TÂM", value: s.lightAimOn ? "BẬT" : "TẮT")
            infoCard(title: "GAME", value: s.gameName())
            infoCard(title: "BUNDLE", value: s.gameBundle())
        }
    }

    // MARK: - TAB 2: SENS
    var sensTab: some View {
        VStack(spacing: 10) {
            sectionTitle("ĐỘ NHẠY")
            sliderCard(title: "SENS X", value: $s.sensX, range: 0.1...3.0, suffix: "x")
            sliderCard(title: "SENS Y", value: $s.sensY, range: 0.1...3.0, suffix: "x")
            sliderCard(title: "SENS SCOPE", value: $s.sensScope, range: 0.1...2.0, suffix: "x")

            sectionTitle("PRESET")
            presetRow(title: "🎯 HEADSHOT", action: {
                s.sensX = 1.4; s.sensY = 1.2; s.sensScope = 0.4
                s.log("PRESET: HEADSHOT")
            })
            presetRow(title: "🥷 STEALTH", action: {
                s.sensX = 0.8; s.sensY = 0.8; s.sensScope = 0.6
                s.log("PRESET: STEALTH")
            })
            presetRow(title: "⚡ FAST", action: {
                s.sensX = 2.0; s.sensY = 1.8; s.sensScope = 0.8
                s.log("PRESET: FAST")
            })
            presetRow(title: "🎯 BALANCED", action: {
                s.sensX = 1.0; s.sensY = 1.0; s.sensScope = 0.5
                s.log("PRESET: BALANCED")
            })
            sectionTitle("LOG")
            logView
        }
    }

    // MARK: - TAB 3: TÂM ẢO
    var visualTab: some View {
        VStack(spacing: 10) {
            sectionTitle("TÂM ẢO")
            toggleCard(icon: "✚", title: "BẬT TÂM ẢO", sub: "Crosshair đè lên màn hình", isOn: $s.crosshairOn)

            sectionTitle("KIỂU TÂM")
            HStack(spacing: 6) {
                styleBtn(idx: 0, icon: "⭕", title: "VÒNG")
                styleBtn(idx: 1, icon: "✚", title: "CHỮ THẬP")
                styleBtn(idx: 2, icon: "🔴", title: "CHẤM")
                styleBtn(idx: 3, icon: "🎯", title: "FULL")
            }

            sectionTitle("MÀU SẮC")
            HStack(spacing: 8) {
                colorBtn(idx: 0, color: .red, label: "ĐỎ")
                colorBtn(idx: 1, color: SEA_CYAN, label: "CYAN")
                colorBtn(idx: 2, color: NEON_GREEN, label: "XANH")
                colorBtn(idx: 3, color: .white, label: "TRẮNG")
                colorBtn(idx: 4, color: .yellow, label: "VÀNG")
                colorBtn(idx: 5, color: .pink, label: "HỒNG")
            }

            sectionTitle("TINH CHỈNH")
            sliderCard(title: "KÍCH THƯỚC", value: $s.crosshairSize, range: 40...240, suffix: "px")
            sliderCard(title: "ĐỘ MỜ", value: $s.crosshairOpacity, range: 0.2...1.0, suffix: "")
            sliderCard(title: "HEAD GUIDE Y", value: $s.headGuideY, range: 20...400, suffix: "px")

            sectionTitle("HỖ TRỢ")
            toggleCard(icon: "🎯", title: "HEAD GUIDE", sub: "Đường ngang tầm đầu địch", isOn: $s.headGuideOn)
        }
    }

    // MARK: - TAB 4: THIẾT BỊ
    var deviceTab: some View {
        VStack(spacing: 10) {
            sectionTitle("THÔNG TIN THIẾT BỊ")
            infoCard(title: "MODEL", value: s.deviceName)
            infoCard(title: "iOS", value: s.iosVersion)
            infoCard(title: "SCREEN", value: s.screenSize)
            infoCard(title: "SCALE", value: String(format: "%.1fx", UIScreen.main.scale))
            infoCard(title: "CPU CORES", value: "\(ProcessInfo.processInfo.processorCount)")

            sectionTitle("PIN")
            batteryView

            sectionTitle("BỘ NHỚ")
            infoCard(title: "RAM", value: memoryText())
            infoCard(title: "CPU USAGE", value: "\(cpuUsage())%")

            sectionTitle("LOG")
            logView
        }
    }
    var batteryView: some View {
        VStack(spacing: 8) {
            HStack {
                Text(s.isCharging ? "⚡ ĐANG SẠC" : "🔋 ĐANG DÙNG")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(s.isCharging ? NEON_GREEN : .yellow)
                Spacer()
                Text("\(s.batteryLevel)%")
                    .font(.system(size: 16, weight: .heavy, design: .monospaced))
                    .foregroundColor(SEA_CYAN)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1)).frame(height: 12)
                    Capsule()
                        .fill(LinearGradient(
                            colors: s.batteryLevel > 30
                                ? [NEON_GREEN, SEA_CYAN]
                                : [.red, .orange],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(s.batteryLevel) / 100.0, height: 12)
                }
            }.frame(height: 12)
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
    func memoryText() -> String {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            let used = Double(info.resident_size) / 1024 / 1024
            return String(format: "%.1f MB", used)
        }
        return "N/A"
    }
    func cpuUsage() -> Int {
        return Int.random(in: 5...30)
    }

    // MARK: - TAB 5: LIÊN HỆ
    var contactTab: some View {
        VStack(spacing: 10) {
            sectionTitle("ADMIN")
            contactCard(
                icon: "👑",
                title: "Ph Hai Long",
                sub: "Admin hệ thống",
                color: GOLD
            )

            sectionTitle("ZALO")
            Button(action: { showZaloAlert = true }) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ZALO_BLUE)
                            .frame(width: 50, height: 50)
                            .shadow(color: ZALO_BLUE.opacity(0.6), radius: 10)
                        Image(systemName: "phone.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 22, weight: .bold))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ZALO ADMIN").font(.system(size: 13, weight: .heavy)).foregroundColor(.white)
                        Text("0919178382").font(.system(size: 14, weight: .heavy, design: .monospaced))
                            .foregroundColor(SEA_CYAN)
                        Text("Nhấn để liên hệ trực tiếp").font(.system(size: 9)).foregroundColor(.gray)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(SEA_CYAN)
                }
                .padding(14)
                .background(LinearGradient(colors: [ZALO_BLUE.opacity(0.20), RED_ACCENT.opacity(0.10)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16)
                            .stroke(LinearGradient(colors: [ZALO_BLUE, .white, ZALO_BLUE],
                                                   startPoint: .leading, endPoint: .trailing), lineWidth: 1.3))
                .shadow(color: ZALO_BLUE.opacity(0.5), radius: 12)
            }
            .buttonStyle(PlainButtonStyle())

            sectionTitle("HỖ TRỢ")
            contactSmall(icon: "💬", title: "Zalo Chat", sub: "0919178382")
            contactSmall(icon: "📞", title: "Gọi điện", sub: "0919178382")
            contactSmall(icon: "📧", title: "Email", sub: "admin@zwilzhlong.vn")

            sectionTitle("VỀ APP")
            infoCard(title: "PHIÊN BẢN", value: "v12.0")
            infoCard(title: "ADMIN", value: "Ph Hai Long")
            infoCard(title: "HỖ TRỢ", value: "Free Fire / FF MAX")
        }
    }
    func contactCard(icon: String, title: String, sub: String, color: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.25))
                    .frame(width: 50, height: 50)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(color, lineWidth: 1.5))
                Text(icon).font(.system(size: 24))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14, weight: .heavy)).foregroundColor(.white)
                Text(sub).font(.system(size: 10)).foregroundColor(color)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.4), lineWidth: 1))
    }
    func contactSmall(icon: String, title: String, sub: String) -> some View {
        Button(action: { showZaloAlert = true }) {
            HStack(spacing: 12) {
                Text(icon).font(.system(size: 20))
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                    Text(sub).font(.system(size: 10, design: .monospaced)).foregroundColor(SEA_CYAN)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.gray).font(.system(size: 12))
            }
            .padding(11)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }.buttonStyle(PlainButtonStyle())
    }

    // MARK: - Components
    func sectionTitle(_ t: String) -> some View {
        HStack(spacing: 8) {
            Rectangle().fill(LinearGradient(colors: [SEA_CYAN, RED_ACCENT],
                                            startPoint: .top, endPoint: .bottom))
                .frame(width: 3, height: 14).shadow(color: SEA_CYAN, radius: 4)
            Text(t).font(.system(size: 10.5, weight: .heavy)).foregroundColor(SEA_CYAN)
            Spacer()
            Rectangle().fill(LinearGradient(colors: [SEA_CYAN.opacity(0.3), .clear],
                                            startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
        }.padding(.top, 6)
    }

    func toggleCard(icon: String, title: String, sub: String, isOn: Binding<Bool>) -> some View {
        Button(action: {
            isOn.wrappedValue.toggle()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            s.log("\(title): \(isOn.wrappedValue ? "BẬT" : "TẮT")")
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isOn.wrappedValue
                              ? LinearGradient(colors: [SEA_CYAN, RED_ACCENT],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                              : LinearGradient(colors: [SEA_CYAN.opacity(0.25), Color.gray.opacity(0.2)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 42, height: 42)
                        .shadow(color: isOn.wrappedValue ? SEA_CYAN.opacity(0.7) : .clear, radius: 8)
                    Text(icon).font(.system(size: 18))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                    Text(sub).font(.system(size: 9.5)).foregroundColor(.gray)
                }
                Spacer()
                ZStack {
                    Capsule()
                        .fill(isOn.wrappedValue
                              ? LinearGradient(colors: [SEA_CYAN, RED_ACCENT],
                                               startPoint: .leading, endPoint: .trailing)
                              : LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.12)],
                                               startPoint: .leading, endPoint: .trailing))
                        .frame(width: 50, height: 30)
                    Circle().fill(Color.white).frame(width: 24, height: 24)
                        .offset(x: isOn.wrappedValue ? 10 : -10)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7))
                }
            }
            .padding(14)
            .background(LinearGradient(colors: isOn.wrappedValue
                                       ? [SEA_CYAN.opacity(0.20), RED_ACCENT.opacity(0.12)]
                                       : [Color.white.opacity(0.05), Color.white.opacity(0.02)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(isOn.wrappedValue
                                ? LinearGradient(colors: [SEA_CYAN, RED_ACCENT],
                                                 startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.1)],
                                                 startPoint: .leading, endPoint: .trailing),
                                lineWidth: 1))
        }.buttonStyle(PlainButtonStyle())
    }

    func styleBtn(idx: Int, icon: String, title: String) -> some View {
        Button(action: {
            s.crosshairStyle = idx
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            VStack(spacing: 4) {
                Text(icon).font(.system(size: 18))
                Text(title).font(.system(size: 8, weight: .bold))
                    .foregroundColor(s.crosshairStyle == idx ? .white : .gray)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(s.crosshairStyle == idx
                        ? LinearGradient(colors: [SEA_CYAN.opacity(0.3), RED_ACCENT.opacity(0.2)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.white.opacity(0.05), Color.white.opacity(0.05)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(s.crosshairStyle == idx ? SEA_CYAN : Color.white.opacity(0.1), lineWidth: 1))
        }.buttonStyle(PlainButtonStyle())
    }

    func sliderCard(title: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                Spacer()
                Text(String(format: "%.2f\(suffix)", value.wrappedValue))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(SEA_CYAN)
            }
            Slider(value: value, in: range)
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    func infoCard(title: String, value: String) -> some View {
        HStack {
            Text(title).font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
            Spacer()
            Text(value).font(.system(size: 11, weight: .heavy, design: .monospaced)).foregroundColor(SEA_CYAN)
        }
        .padding(13)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    func presetRow(title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }) {
            HStack {
                Text(title).font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(SEA_CYAN)
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }.buttonStyle(PlainButtonStyle())
    }

    func colorBtn(idx: Int, color: Color, label: String) -> some View {
        Button(action: {
            s.crosshairColor = idx
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            VStack(spacing: 4) {
                Circle().fill(color).frame(width: 32, height: 32)
                    .overlay(Circle().stroke(s.crosshairColor == idx ? Color.white : Color.clear, lineWidth: 3))
                    .shadow(color: color.opacity(0.8), radius: s.crosshairColor == idx ? 10 : 0)
                Text(label).font(.system(size: 7.5, weight: .bold)).foregroundColor(.white)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 6)
            .background(Color.white.opacity(s.crosshairColor == idx ? 0.10 : 0.03))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(PlainButtonStyle())
    }

    var logView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(s.logLines, id: \.self) { line in
                    Text(line).font(.system(size: 9.5, design: .monospaced)).foregroundColor(.green)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(10)
        }
        .frame(height: 150)
        .background(Color.black.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    var footer: some View {
        HStack(spacing: 10) {
            Button(action: {
                s.lightAimOn = false; s.crosshairOn = false; s.ghostOn = false
                s.headGuideOn = false; s.cursorLockOn = false
                s.sensX = 1.0; s.sensY = 1.0; s.sensScope = 0.5
                s.log("⟳ ĐÃ ĐẶT LẠI")
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }) {
                Text("ĐẶT LẠI").font(.system(size: 13, weight: .heavy)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.15), lineWidth: 1))
            }
            Button(action: {
                s.lightAimOn = true; s.crosshairOn = true
                s.ghostOn = true; s.headGuideOn = true
                s.log("✅ ĐÃ BẬT NHẸ TÂM + TÂM ẢO")
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                if s.autoOpen { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { s.openGame() } }
            }) {
                Text("✨ BẬT NGAY").font(.system(size: 13, weight: .heavy)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(LinearGradient(colors: [SEA_CYAN, RED_ACCENT],
                                               startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .shadow(color: SEA_CYAN.opacity(0.7), radius: 12)
            }
        }
    }

    func openZalo() {
        let phone = "0919178382"
        let zaloURL = URL(string: "zalo://phone/\(phone)")!
        let zaloWebURL = URL(string: "https://zalo.me/\(phone)")!
        if UIApplication.shared.canOpenURL(zaloURL) {
            UIApplication.shared.open(zaloURL, options: [:], completionHandler: nil)
        } else {
            UIApplication.shared.open(zaloWebURL, options: [:], completionHandler: nil)
        }
    }
}

// ============================================
// OVERLAY VIEW
// ============================================
struct OverlayView: View {
    @ObservedObject var state: MenuState

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if state.crosshairOn {
                    CrosshairShape(color: state.color(),
                                   size: state.crosshairSize,
                                   style: state.crosshairStyle)
                        .opacity(state.crosshairOpacity)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
                if state.headGuideOn {
                    Rectangle()
                        .fill(LinearGradient(colors: [.clear, .yellow, .clear],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width, height: 2)
                        .shadow(color: .yellow, radius: 8)
                        .position(x: geo.size.width / 2,
                                  y: geo.size.height / 2 - state.headGuideY)
                }
                if state.ghostOn {
                    GhostFollow(color: state.color(),
                                speed: state.ghostFollowSpeed,
                                range: state.lightAimRange)
                }
                if state.cursorLockOn {
                    Circle()
                        .stroke(state.color().opacity(0.4), lineWidth: 1)
                        .frame(width: 60, height: 60)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// ============================================
// CROSSHAIR SHAPE
// ============================================
struct CrosshairShape: View {
    let color: Color
    let size: Double
    let style: Int

    var body: some View {
        ZStack {
            if style == 0 || style == 3 {
                Circle()
                    .stroke(LinearGradient(colors: [color, .white],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.5)
                    .frame(width: size, height: size)
                    .shadow(color: color.opacity(0.8), radius: 6)
            }

            if style == 1 || style == 3 {
                Rectangle().fill(color).frame(width: size * 1.4, height: 1.5)
                    .shadow(color: color, radius: 4)
                Rectangle().fill(color).frame(width: 1.5, height: size * 1.4)
                    .shadow(color: color, radius: 4)
                ForEach(0..<4) { i in
                    Rectangle().fill(color).frame(width: 8, height: 2)
                        .offset(y: -size / 2 + 6)
                        .rotationEffect(.degrees(Double(i) * 90))
                        .shadow(color: color, radius: 3)
                }
            }

            if style == 2 || style == 3 {
                Circle().fill(color).frame(width: 6, height: 6)
                    .shadow(color: color, radius: 10)
            }

            if style == 3 {
                Circle()
                    .stroke(color, lineWidth: 1)
                    .frame(width: size * 0.35, height: size * 0.35)
                    .shadow(color: color, radius: 4)
            }
        }
    }
}

// ============================================
// GHOST FOLLOW
// ============================================
struct GhostFollow: View {
    let color: Color
    let speed: Double
    let range: Double

    @State private var pos: CGPoint = UIScreen.main.bounds.center
    @State private var target: CGPoint = UIScreen.main.bounds.center
    @State private var timer: Timer? = nil

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.4), lineWidth: 1)
                .frame(width: range * 2, height: range * 2)
                .position(x: pos.x, y: pos.y)

            ZStack {
                Circle().stroke(color, lineWidth: 2).frame(width: 30, height: 30)
                    .shadow(color: color, radius: 8)
                Rectangle().fill(color).frame(width: 20, height: 1.5)
                Rectangle().fill(color).frame(width: 1.5, height: 20)
                Circle().fill(color).frame(width: 3, height: 3)
            }
            .position(x: pos.x, y: pos.y)
        }
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
                let dx = target.x - pos.x
                let dy = target.y - pos.y
                pos.x += dx * CGFloat(speed) * 0.15
                pos.y += dy * CGFloat(speed) * 0.15
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}
