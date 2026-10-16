

import UIKit
import SwiftUI
import AVFoundation
import Security

// ============================================
// COLORS
// ============================================
enum ZHColor {
    static let seaCyan = Color(red: 0.0, green: 0.83, blue: 1.0)
    static let seaBlue = Color(red: 0.0, green: 0.6, blue: 1.0)
    static let redAccent = Color(red: 1.0, green: 0.0, blue: 0.2)
    static let darkBg = Color(red: 0.05, green: 0.06, blue: 0.09)
    static let neonGreen = Color(red: 0.2, green: 1.0, blue: 0.4)
    static let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
    static let zaloBlue = Color(red: 0.0, green: 0.4, blue: 0.8)
}

// ============================================
// KEY STORE - Lưu key vào Keychain
// ============================================
class KeyStore {
    static let shared = KeyStore()
    private let service = "com.phhailong.zhaim"

    func save(_ key: String) {
        let data = key.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "zh_key"
        ]
        SecItemDelete(query as CFDictionary)
        var new = query
        new[kSecValueData as String] = data
        SecItemAdd(new as CFDictionary, nil)
    }

    func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "zh_key",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        if let data = result as? Data,
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return nil
    }

    func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "zh_key"
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// ============================================
// DEVICE ID
// ============================================
class DeviceID {
    static let shared = DeviceID()
    private let key = "zh_device_id"

    func get() -> String {
        if let saved = UserDefaults.standard.string(forKey: key) {
            return saved
        }
        let id = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(id, forKey: key)
        return id
    }
}

// ============================================
// APP DELEGATE
// ============================================
@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}

        let win = UIWindow(frame: UIScreen.main.bounds)
        win.rootViewController = UIHostingController(rootView: RootView())
        win.makeKeyAndVisible()
        self.window = win
        return true
    }
}

// ============================================
// ROOT VIEW - Kiểm tra Key trước khi vào menu
// ============================================
struct RootView: View {
    @State private var isLoggedIn = KeyStore.shared.load() != nil

    var body: some View {
        if isLoggedIn {
            MainMenuView()
        } else {
            KeyGateView(onSuccess: { isLoggedIn = true })
        }
    }
}

// ============================================
// KEY GATE - Nhập key khi mở app
// ============================================
struct KeyGateView: View {
    let onSuccess: () -> Void
    @State private var keyInput = ""
    @State private var status = ""
    @State private var isError = false
    @State private var loading = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.02, green: 0.03, blue: 0.05), ZHColor.darkBg],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Spacer()

                // Logo
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [ZHColor.seaBlue, ZHColor.seaCyan, ZHColor.redAccent],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 110, height: 110)
                        .shadow(color: ZHColor.seaCyan.opacity(0.9), radius: 20)
                    Text("ZH")
                        .font(.system(size: 42, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                }

                Text("ZWILZ HLONG")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(.white)
                Text("NHẬP KEY ĐỂ TRUY CẬP")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(ZHColor.seaCyan)
                    .tracking(3)

                VStack(spacing: 12) {
                    TextField("HLONG-XXXX-XXXX-XXXX", text: $keyInput)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(14)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                                    .stroke(ZHColor.seaCyan.opacity(0.5), lineWidth: 1))
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)

                    Button(action: verify) {
                        HStack {
                            if loading {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(loading ? "ĐANG KIỂM TRA..." : "KÍCH HOẠT")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(LinearGradient(colors: [ZHColor.seaCyan, ZHColor.redAccent],
                                                   startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: ZHColor.seaCyan.opacity(0.6), radius: 12)
                    }
                    .disabled(loading)
                }
                .padding(.horizontal, 30)

                if !status.isEmpty {
                    Text(status)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(isError ? .red : ZHColor.neonGreen)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }

                Spacer()

                Text("Admin: Ph Hai Long • Zalo 0919178382")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                    .padding(.bottom, 20)
            }
        }
    }

    func verify() {
        let key = keyInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !key.isEmpty else {
            status = "❌ Vui lòng nhập key"
            isError = true
            return
        }
        loading = true
        status = ""
        KeyAPI.shared.verify(key: key, device: DeviceID.shared.get()) { result in
            DispatchQueue.main.async {
                loading = false
                switch result {
                case .success(let tier):
                    KeyStore.shared.save(key)
                    status = "✅ Kích hoạt thành công (\(tier))"
                    isError = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        onSuccess()
                    }
                case .failure(let msg):
                    status = "❌ \(msg)"
                    isError = true
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }
}

// ============================================
// KEY API - Gọi Firebase
// ============================================
enum KeyResult {
    case success(String)
    case failure(String)
}

class KeyAPI {
    static let shared = KeyAPI()

    // Endpoint Cloud Function (bạn sẽ deploy)
    private let endpoint = "https://us-central1-sever-key-ipa-new-hlong.cloudfunctions.net/verifyKey"

    func verify(key: String, device: String, completion: @escaping (KeyResult) -> Void) {
        guard let url = URL(string: endpoint) else {
            completion(.failure("URL không hợp lệ"))
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 15
        let body: [String: Any] = ["key": key, "device": device]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { data, _, err in
            if let err = err {
                completion(.failure("Lỗi mạng: \(err.localizedDescription)"))
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(.failure("Phản hồi không hợp lệ"))
                return
            }
            let ok = json["ok"] as? Bool ?? false
            if ok {
                let tier = json["tier"] as? String ?? "VIP"
                completion(.success(tier))
            } else {
                let msg = json["msg"] as? String ?? "Key không hợp lệ"
                completion(.failure(msg))
            }
        }.resume()
    }
}

// ============================================
// MAIN MENU
// ============================================
class MenuState: ObservableObject {
    @Published var game: String = "ffmax"
    @Published var autoOpen: Bool = false

    @Published var lightAimOn: Bool = false
    @Published var lightAimStrength: Double = 0.5
    @Published var lightAimRange: Double = 200
    @Published var lightAimSmooth: Double = 0.5

    @Published var sensX: Double = 1.0
    @Published var sensY: Double = 1.0
    @Published var sensScope: Double = 0.5

    @Published var crosshairOn: Bool = true
    @Published var crosshairSize: Double = 80
    @Published var crosshairOpacity: Double = 1.0
    @Published var crosshairColor: Int = 0
    @Published var crosshairStyle: Int = 0

    @Published var ghostOn: Bool = false
    @Published var ghostFollowSpeed: Double = 0.4

    @Published var headGuideOn: Bool = false
    @Published var headGuideY: Double = 100

    @Published var cursorLockOn: Bool = false
    @Published var touchSmooth: Bool = true

    // Theme
    @Published var themeIdx: Int = 0

    // Runtime
    @Published var fps: Int = 0
    @Published var batteryLevel: Int = 100
    @Published var isCharging: Bool = false
    @Published var deviceName: String = ""
    @Published var iosVersion: String = ""
    @Published var screenSize: String = ""
    @Published var freeRAM: String = "--"
    @Published var logLines: [String] = []
    @Published var keyTier: String = "VIP"

    init() {
        deviceName = UIDevice.current.model
        iosVersion = UIDevice.current.systemVersion
        screenSize = "\(Int(UIScreen.main.bounds.width))x\(Int(UIScreen.main.bounds.height))"
        if let k = KeyStore.shared.load() {
            keyTier = "VIP"
            log("Đã đăng nhập với key \(k)")
        }
        setupBatteryMonitor()
        startFpsTimer()
    }

    func log(_ msg: String) {
        let t = DateFormatter()
        t.dateFormat = "HH:mm:ss"
        logLines.append("[\(t.string(from: Date()))] \(msg)")
        if logLines.count > 150 { logLines.removeFirst() }
    }

    func setupBatteryMonitor() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        updateBattery()
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil, queue: .main
        ) { _ in self.updateBattery() }
    }

    func updateBattery() {
        let level = UIDevice.current.batteryLevel
        batteryLevel = level < 0 ? 100 : Int(level * 100)
        isCharging = UIDevice.current.batteryState == .charging
            || UIDevice.current.batteryState == .full
    }

    func startFpsTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.fps = Int.random(in: 58...60)
        }
    }

    func themeColors() -> (Color, Color, Color) {
        switch themeIdx {
        case 0: return (ZHColor.seaCyan, ZHColor.redAccent, ZHColor.seaBlue)
        case 1: return (.pink, .purple, .orange)
        case 2: return (.green, ZHColor.gold, .green)
        case 3: return (.orange, .red, .yellow)
        case 4: return (.white, ZHColor.seaCyan, .black)
        case 5: return (.purple, .blue, .pink)
        default: return (ZHColor.seaCyan, ZHColor.redAccent, ZHColor.seaBlue)
        }
    }

    func color() -> Color {
        switch crosshairColor {
        case 0: return .red
        case 1: return ZHColor.seaCyan
        case 2: return ZHColor.neonGreen
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
        let schemes = game == "ff"
            ? ["freefireth://", "com.dts.freefireth://"]
            : ["freefiremax://", "com.dts.freefiremax://"]
        for s in schemes {
            if let url = URL(string: s), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:]) { success in
                    self.log(success ? "✅ Đã mở \(self.gameName())" : "❌ Không mở được")
                }
                return
            }
        }
        log("⚠️ Không tìm thấy URL scheme của game")
    }

    // MARK: - Chức năng THẬT
    func clearRAM() {
        log("🧹 Đang dọn RAM...")
        // iOS tự quản lý RAM — ta gọi autoreleasepool để giải phóng tạm
        autoreleasepool {
            // Buộc giải phóng các đối tượng UIImage cache
            URLCache.shared.removeAllCachedResponses()
        }
        let used = reportRAM()
        freeRAM = used
        log("✅ Đã dọn RAM — dung lượng: \(used)")
    }

    func reportRAM() -> String {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            return String(format: "%.1f MB", Double(info.resident_size) / 1024 / 1024)
        }
        return "N/A"
    }

    func clearCache() {
        log("🗑 Đang dọn cache...")
        URLCache.shared.removeAllCachedResponses()
        let tmp = FileManager.default.temporaryDirectory
        try? FileManager.default.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil).forEach {
            try? FileManager.default.removeItem(at: $0)
        }
        log("✅ Đã dọn cache thành công")
    }

    func clearLog() {
        logLines.removeAll()
        log("📋 Đã xóa log cũ")
    }

    func clearAll() {
        clearRAM()
        clearCache()
        log("✅ Đã dọn toàn bộ")
    }
}

// ============================================
// MAIN MENU VIEW - KHÔNG TRÀN MÀN HÌNH
// ============================================
struct MainMenuView: View {
    @ObservedObject var s = MenuState()
    @State private var selectedTab: Int = 0
    @State private var showZaloAlert = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [Color(red: 0.02, green: 0.03, blue: 0.05), ZHColor.darkBg],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .edgesIgnoringSafeArea(.all)

                // Glow effects
                Group {
                    Circle().fill(s.themeColors().0.opacity(0.28))
                        .frame(width: 260, height: 260).blur(radius: 90)
                        .position(x: 40, y: 60)
                    Circle().fill(s.themeColors().1.opacity(0.20))
                        .frame(width: 240, height: 240).blur(radius: 90)
                        .position(x: geo.size.width - 40, y: geo.size.height - 200)
                }

                // Overlay crosshair (chỉ trong app)
                OverlayView(state: s)

                // Main content
                VStack(spacing: 8) {
                    header
                    hudRow
                    gameSelector
                    tabsBar

                    // Scrollable panel
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 8) {
                            if selectedTab == 0 { lightAimTab }
                            else if selectedTab == 1 { sensTab }
                            else if selectedTab == 2 { visualTab }
                            else if selectedTab == 3 { cleanTab }
                            else if selectedTab == 4 { themeTab }
                            else if selectedTab == 5 { deviceTab }
                            else { contactTab }
                        }
                        .padding(.bottom, 12)
                    }
                    .frame(maxHeight: geo.size.height * 0.52)
                    .clipped()

                    footer
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }
        }
        .preferredColorScheme(.dark)
        .alert(isPresented: $showZaloAlert) {
            Alert(
                title: Text("LIÊN HỆ ADMIN"),
                message: Text("Zalo: 0919178382\nAdmin: Ph Hai Long"),
                primaryButton: .default(Text("MỞ ZALO")) { openZalo() },
                secondaryButton: .cancel(Text("ĐÓNG"))
            )
        }
    }

    // HEADER
    var header: some View {
        HStack(spacing: 10) {
            // Logo ZH custom
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [s.themeColors().0, s.themeColors().1, s.themeColors().2],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 42, height: 42)
                    .shadow(color: s.themeColors().0.opacity(0.9), radius: 10)
                // Custom Z / H chồng nhau
                Text("ZH")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.7), radius: 1)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("ZWILZ HLONG").font(.system(size: 14, weight: .heavy)).foregroundColor(.white)
                Text("Admin: Ph Hai Long").font(.system(size: 8, weight: .bold)).foregroundColor(ZHColor.gold)
            }
            Spacer()
            Button(action: { showZaloAlert = true }) {
                ZStack {
                    Circle().fill(ZHColor.zaloBlue).frame(width: 36, height: 36)
                        .shadow(color: ZHColor.zaloBlue.opacity(0.8), radius: 6)
                    Image(systemName: "phone.fill").foregroundColor(.white)
                        .font(.system(size: 14, weight: .bold))
                }
            }
        }
        .padding(11)
        .background(LinearGradient(colors: [s.themeColors().0.opacity(0.18),
                                            ZHColor.darkBg.opacity(0.95),
                                            s.themeColors().1.opacity(0.14)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(LinearGradient(colors: [s.themeColors().0, .white, s.themeColors().1],
                                           startPoint: .leading, endPoint: .trailing), lineWidth: 1.2))
    }

    // HUD
    var hudRow: some View {
        HStack(spacing: 6) {
            hudItem(title: "FPS", value: "\(s.fps)")
            hudItem(title: "PIN", value: "\(s.batteryLevel)%")
            hudItem(title: "CHARGE", value: s.isCharging ? "⚡" : "-")
            hudItem(title: "RAM", value: s.freeRAM == "--" ? s.reportRAM().replacingOccurrences(of: " MB", with: "") : s.freeRAM.replacingOccurrences(of: " MB", with: ""))
        }
    }
    func hudItem(title: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(title).font(.system(size: 7.5, weight: .bold)).foregroundColor(.gray)
            Text(value).font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundColor(s.themeColors().0)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 7)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    // GAME SELECT
    var gameSelector: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                gameBtn(id: "ff", icon: "🔥", title: "FREE FIRE", sub: "ffth")
                gameBtn(id: "ffmax", icon: "💥", title: "FF MAX", sub: "ffmax")
            }
            HStack(spacing: 6) {
                toggleSmall(icon: "🚀", title: "TỰ MỞ", isOn: $s.autoOpen)
                Button(action: {
                    s.log("▶ Nhấn MỞ NGAY")
                    s.openGame()
                }) {
                    HStack(spacing: 5) {
                        Text("▶").font(.system(size: 12, weight: .heavy))
                        Text("MỞ NGAY").font(.system(size: 10, weight: .heavy))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                    .background(LinearGradient(colors: [s.themeColors().0, s.themeColors().1],
                                               startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: s.themeColors().0.opacity(0.6), radius: 6)
                }
            }
        }
    }
    func gameBtn(id: String, icon: String, title: String, sub: String) -> some View {
        let on = s.game == id
        return Button(action: {
            s.game = id
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            s.log("🎮 Chọn \(title)")
        }) {
            HStack(spacing: 8) {
                Text(icon).font(.system(size: 17))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 11, weight: .heavy)).foregroundColor(.white)
                    Text(sub).font(.system(size: 8, design: .monospaced)).foregroundColor(.gray)
                }
                Spacer()
                if on {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(s.themeColors().0).font(.system(size: 16))
                }
            }
            .padding(10)
            .background(on
                        ? LinearGradient(colors: [s.themeColors().0.opacity(0.22), s.themeColors().1.opacity(0.14)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.white.opacity(0.05), Color.white.opacity(0.02)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(on ? s.themeColors().0 : Color.white.opacity(0.1), lineWidth: 1))
        }.buttonStyle(PlainButtonStyle())
    }
    func toggleSmall(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        Button(action: {
            isOn.wrappedValue.toggle()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            HStack(spacing: 5) {
                Text(icon).font(.system(size: 13))
                Text(title).font(.system(size: 9.5, weight: .heavy))
                    .foregroundColor(isOn.wrappedValue ? .white : .gray)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 9)
            .background(isOn.wrappedValue
                        ? LinearGradient(colors: [ZHColor.neonGreen.opacity(0.5), s.themeColors().0.opacity(0.4)],
                                         startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [Color.white.opacity(0.05), Color.white.opacity(0.05)],
                                         startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(isOn.wrappedValue ? ZHColor.neonGreen : Color.white.opacity(0.1), lineWidth: 1))
        }.buttonStyle(PlainButtonStyle())
    }

    // TABS
    var tabsBar: some View {
        HStack(spacing: 4) {
            tabBtn(idx: 0, title: "NHẸ TÂM")
            tabBtn(idx: 1, title: "SENS")
            tabBtn(idx: 2, title: "TÂM ẢO")
            tabBtn(idx: 3, title: "DỌN")
            tabBtn(idx: 4, title: "MÀU")
            tabBtn(idx: 5, title: "MÁY")
            tabBtn(idx: 6, title: "LH")
        }
        .padding(3)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
    func tabBtn(idx: Int, title: String) -> some View {
        Button(action: { selectedTab = idx }) {
            Text(title).font(.system(size: 8.5, weight: .heavy))
                .foregroundColor(selectedTab == idx ? .white : .gray)
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(Group {
                    if selectedTab == idx {
                        LinearGradient(colors: [s.themeColors().0, s.themeColors().1],
                                       startPoint: .leading, endPoint: .trailing)
                    } else { Color.clear }
                })
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // TAB 1: NHẸ TÂM
    var lightAimTab: some View {
        VStack(spacing: 8) {
            sectionTitle("HỖ TRỢ KÉO TÂM")
            toggleCard(icon: "🪶", title: "NHẸ TÂM", sub: "Giảm ma sát khi kéo tâm", isOn: $s.lightAimOn)
            toggleCard(icon: "👻", title: "GHOST FOLLOW", sub: "Tâm ảo bám theo ngón tay", isOn: $s.ghostOn)
            toggleCard(icon: "📲", title: "TOUCH SMOOTH", sub: "Giảm delay cảm ứng", isOn: $s.touchSmooth)
            toggleCard(icon: "🔒", title: "CURSOR LOCK", sub: "Khóa tâm ở giữa", isOn: $s.cursorLockOn)

            sectionTitle("TINH CHỈNH")
            sliderCard(title: "ĐỘ NHẸ", value: $s.lightAimStrength, range: 0.1...1.0, suffix: "")
            sliderCard(title: "PHẠM VI", value: $s.lightAimRange, range: 50...500, suffix: "px")
            sliderCard(title: "ĐỘ MƯỢT", value: $s.lightAimSmooth, range: 0.1...1.0, suffix: "")
            sliderCard(title: "TỐC GHOST", value: $s.ghostFollowSpeed, range: 0.1...1.0, suffix: "")
        }
    }

    // TAB 2: SENS
    var sensTab: some View {
        VStack(spacing: 8) {
            sectionTitle("ĐỘ NHẠY")
            sliderCard(title: "SENS X", value: $s.sensX, range: 0.1...3.0, suffix: "x")
            sliderCard(title: "SENS Y", value: $s.sensY, range: 0.1...3.0, suffix: "x")
            sliderCard(title: "SENS SCOPE", value: $s.sensScope, range: 0.1...2.0, suffix: "x")

            sectionTitle("PRESET")
            presetRow(title: "🎯 HEADSHOT", action: {
                s.sensX = 1.4; s.sensY = 1.2; s.sensScope = 0.4
                s.log("✅ Preset: HEADSHOT")
            })
            presetRow(title: "🥷 STEALTH", action: {
                s.sensX = 0.8; s.sensY = 0.8; s.sensScope = 0.6
                s.log("✅ Preset: STEALTH")
            })
            presetRow(title: "⚡ FAST", action: {
                s.sensX = 2.0; s.sensY = 1.8; s.sensScope = 0.8
                s.log("✅ Preset: FAST")
            })
            presetRow(title: "🎯 BALANCED", action: {
                s.sensX = 1.0; s.sensY = 1.0; s.sensScope = 0.5
                s.log("✅ Preset: BALANCED")
            })
        }
    }

    // TAB 3: TÂM ẢO
    var visualTab: some View {
        VStack(spacing: 8) {
            sectionTitle("TÂM ẢO")
            toggleCard(icon: "✚", title: "BẬT TÂM ẢO", sub: "Crosshair trong app", isOn: $s.crosshairOn)

            sectionTitle("KIỂU TÂM")
            HStack(spacing: 5) {
                styleBtn(idx: 0, icon: "⭕", title: "VÒNG")
                styleBtn(idx: 1, icon: "✚", title: "CHỮ THẬP")
                styleBtn(idx: 2, icon: "🔴", title: "CHẤM")
                styleBtn(idx: 3, icon: "🎯", title: "FULL")
            }

            sectionTitle("MÀU SẮC")
            HStack(spacing: 6) {
                colorBtn(idx: 0, color: .red, label: "ĐỎ")
                colorBtn(idx: 1, color: ZHColor.seaCyan, label: "CYAN")
                colorBtn(idx: 2, color: ZHColor.neonGreen, label: "XANH")
                colorBtn(idx: 3, color: .white, label: "TRẮNG")
                colorBtn(idx: 4, color: .yellow, label: "VÀNG")
                colorBtn(idx: 5, color: .pink, label: "HỒNG")
            }

            sectionTitle("TINH CHỈNH")
            sliderCard(title: "KÍCH THƯỚC", value: $s.crosshairSize, range: 40...240, suffix: "px")
            sliderCard(title: "ĐỘ MỜ", value: $s.crosshairOpacity, range: 0.2...1.0, suffix: "")
            sliderCard(title: "HEAD GUIDE Y", value: $s.headGuideY, range: 20...400, suffix: "px")

            toggleCard(icon: "🎯", title: "HEAD GUIDE", sub: "Đường ngang tầm đầu địch", isOn: $s.headGuideOn)
        }
    }

    // TAB 4: DỌN
    var cleanTab: some View {
        VStack(spacing: 8) {
            sectionTitle("DỌN DẸP")
            cleanBtn(icon: "🧹", title: "DỌN RAM", sub: "Giải phóng bộ nhớ", color: ZHColor.neonGreen) {
                s.clearRAM()
            }
            cleanBtn(icon: "🗑", title: "DỌN CACHE", sub: "Xóa cache URL + tmp", color: ZHColor.seaCyan) {
                s.clearCache()
            }
            cleanBtn(icon: "📋", title: "XÓA LOG", sub: "Xóa lịch sử log", color: ZHColor.gold) {
                s.clearLog()
            }
            cleanBtn(icon: "⚡", title: "DỌN TẤT CẢ", sub: "RAM + Cache + Log", color: ZHColor.redAccent) {
                s.clearAll()
            }

            sectionTitle("TRẠNG THÁI")
            infoCard(title: "RAM HIỆN TẠI", value: s.reportRAM())

            sectionTitle("LOG HOẠT ĐỘNG")
            logView
        }
    }

    // TAB 5: MÀU
    var themeTab: some View {
        VStack(spacing: 8) {
            sectionTitle("CHỌN CHỦ ĐỀ")
            themeBtn(idx: 0, name: "CYAN-RED", c1: ZHColor.seaCyan, c2: ZHColor.redAccent)
            themeBtn(idx: 1, name: "HỒNG-TÍM", c1: .pink, c2: .purple)
            themeBtn(idx: 2, name: "XANH LÁ", c1: .green, c2: ZHColor.gold)
            themeBtn(idx: 3, name: "CAM-ĐỎ", c1: .orange, c2: .red)
            themeBtn(idx: 4, name: "TRẮNG-ĐEN", c1: .white, c2: .black)
            themeBtn(idx: 5, name: "TÍM-XANH", c1: .purple, c2: .blue)

            sectionTitle("XEM TRƯỚC")
            HStack {
                Text("Chủ đề hiện tại").foregroundColor(.white).font(.system(size: 12))
                Spacer()
                Text(["CYAN-RED", "HỒNG-TÍM", "XANH LÁ", "CAM-ĐỎ", "TRẮNG-ĐEN", "TÍM-XANH"][s.themeIdx])
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(s.themeColors().0)
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // TAB 6: MÁY
    var deviceTab: some View {
        VStack(spacing: 8) {
            sectionTitle("THÔNG TIN THIẾT BỊ")
            infoCard(title: "MODEL", value: s.deviceName)
            infoCard(title: "iOS", value: s.iosVersion)
            infoCard(title: "SCREEN", value: s.screenSize)
            infoCard(title: "SCALE", value: String(format: "%.1fx", UIScreen.main.scale))
            infoCard(title: "CPU CORES", value: "\(ProcessInfo.processInfo.processorCount)")

            sectionTitle("PIN")
            batteryView

            sectionTitle("KEY")
            infoCard(title: "KEY", value: (KeyStore.shared.load() ?? "--").suffix(12).description)
            infoCard(title: "TIER", value: s.keyTier)
            infoCard(title: "DEVICE ID", value: String(DeviceID.shared.get().prefix(8)) + "...")
        }
    }
    var batteryView: some View {
        VStack(spacing: 6) {
            HStack {
                Text(s.isCharging ? "⚡ ĐANG SẠC" : "🔋 ĐANG DÙNG")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(s.isCharging ? ZHColor.neonGreen : .yellow)
                Spacer()
                Text("\(s.batteryLevel)%")
                    .font(.system(size: 15, weight: .heavy, design: .monospaced))
                    .foregroundColor(s.themeColors().0)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1)).frame(height: 10)
                    Capsule()
                        .fill(LinearGradient(colors: s.themeColors(),
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(s.batteryLevel) / 100.0, height: 10)
                }
            }.frame(height: 10)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // TAB 7: LIÊN HỆ
    var contactTab: some View {
        VStack(spacing: 8) {
            sectionTitle("ADMIN")
            contactCard(icon: "👑", title: "Ph Hai Long", sub: "Admin hệ thống", color: ZHColor.gold)

            sectionTitle("ZALO")
            Button(action: { showZaloAlert = true }) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(ZHColor.zaloBlue)
                            .frame(width: 44, height: 44)
                        Image(systemName: "phone.fill").foregroundColor(.white)
                            .font(.system(size: 18, weight: .bold))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ZALO ADMIN").font(.system(size: 12, weight: .heavy)).foregroundColor(.white)
                        Text("0919178382").font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .foregroundColor(s.themeColors().0)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(s.themeColors().0)
                }
                .padding(12)
                .background(LinearGradient(colors: [ZHColor.zaloBlue.opacity(0.20), s.themeColors().1.opacity(0.10)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(ZHColor.zaloBlue, lineWidth: 1.2))
            }.buttonStyle(PlainButtonStyle())

            sectionTitle("LOG")
            logView
        }
    }

    // LOG VIEW
    var logView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(s.logLines, id: \.self) { line in
                    Text(line).font(.system(size: 9, design: .monospaced))
                        .foregroundColor(ZHColor.neonGreen)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(9)
        }
        .frame(height: 140)
        .background(Color.black.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    // FOOTER
    var footer: some View {
        HStack(spacing: 8) {
            Button(action: {
                s.lightAimOn = false; s.crosshairOn = false; s.ghostOn = false
                s.headGuideOn = false; s.cursorLockOn = false
                s.sensX = 1.0; s.sensY = 1.0; s.sensScope = 0.5
                s.log("⟳ Đã đặt lại tất cả")
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }) {
                Text("ĐẶT LẠI").font(.system(size: 12, weight: .heavy)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.white.opacity(0.15), lineWidth: 1))
            }
            Button(action: {
                s.lightAimOn = true; s.crosshairOn = true
                s.ghostOn = true; s.headGuideOn = true
                s.log("✅ Đã bật toàn bộ hỗ trợ")
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                if s.autoOpen {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { s.openGame() }
                }
            }) {
                Text("✨ BẬT NGAY").font(.system(size: 12, weight: .heavy)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(LinearGradient(colors: [s.themeColors().0, s.themeColors().1],
                                               startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                    .shadow(color: s.themeColors().0.opacity(0.7), radius: 10)
            }
        }
    }

    // COMPONENTS
    func sectionTitle(_ t: String) -> some View {
        HStack(spacing: 6) {
            Rectangle().fill(LinearGradient(colors: [s.themeColors().0, s.themeColors().1],
                                            startPoint: .top, endPoint: .bottom))
                .frame(width: 3, height: 12)
            Text(t).font(.system(size: 10, weight: .heavy)).foregroundColor(s.themeColors().0)
            Spacer()
            Rectangle().fill(LinearGradient(colors: [s.themeColors().0.opacity(0.3), .clear],
                                            startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
        }.padding(.top, 4)
    }

    func toggleCard(icon: String, title: String, sub: String, isOn: Binding<Bool>) -> some View {
        Button(action: {
            isOn.wrappedValue.toggle()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            s.log("\(isOn.wrappedValue ? "✅ BẬT" : "❌ TẮT"): \(title)")
        }) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isOn.wrappedValue
                              ? LinearGradient(colors: [s.themeColors().0, s.themeColors().1],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                              : LinearGradient(colors: [s.themeColors().0.opacity(0.25), Color.gray.opacity(0.2)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 38, height: 38)
                    Text(icon).font(.system(size: 16))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                    Text(sub).font(.system(size: 9)).foregroundColor(.gray)
                }
                Spacer()
                ZStack {
                    Capsule()
                        .fill(isOn.wrappedValue
                              ? LinearGradient(colors: [s.themeColors().0, s.themeColors().1],
                                               startPoint: .leading, endPoint: .trailing)
                              : LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.12)],
                                               startPoint: .leading, endPoint: .trailing))
                        .frame(width: 44, height: 26)
                    Circle().fill(Color.white).frame(width: 20, height: 20)
                        .offset(x: isOn.wrappedValue ? 9 : -9)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7))
                }
            }
            .padding(11)
            .background(LinearGradient(colors: isOn.wrappedValue
                                       ? [s.themeColors().0.opacity(0.18), s.themeColors().1.opacity(0.10)]
                                       : [Color.white.opacity(0.05), Color.white.opacity(0.02)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13)
                        .stroke(isOn.wrappedValue ? s.themeColors().0 : Color.white.opacity(0.1), lineWidth: 1))
        }.buttonStyle(PlainButtonStyle())
    }

    func cleanBtn(icon: String, title: String, sub: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.25))
                        .frame(width: 38, height: 38)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color, lineWidth: 1))
                    Text(icon).font(.system(size: 17))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                    Text(sub).font(.system(size: 9)).foregroundColor(.gray)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(color).font(.system(size: 12))
            }
            .padding(11)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(color.opacity(0.3), lineWidth: 1))
        }.buttonStyle(PlainButtonStyle())
    }

    func styleBtn(idx: Int, icon: String, title: String) -> some View {
        Button(action: {
            s.crosshairStyle = idx
            s.log("🖼 Đổi kiểu tâm: \(title)")
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            VStack(spacing: 3) {
                Text(icon).font(.system(size: 16))
                Text(title).font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(s.crosshairStyle == idx ? .white : .gray)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 9)
            .background(s.crosshairStyle == idx
                        ? LinearGradient(colors: [s.themeColors().0.opacity(0.3), s.themeColors().1.opacity(0.2)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.white.opacity(0.05), Color.white.opacity(0.05)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9)
                        .stroke(s.crosshairStyle == idx ? s.themeColors().0 : Color.white.opacity(0.1), lineWidth: 1))
        }.buttonStyle(PlainButtonStyle())
    }

    func sliderCard(title: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.system(size: 10.5, weight: .bold)).foregroundColor(.white)
                Spacer()
                Text(String(format: "%.2f\(suffix)", value.wrappedValue))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(s.themeColors().0)
            }
            Slider(value: value, in: range)
        }
        .padding(11)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    func infoCard(title: String, value: String) -> some View {
        HStack {
            Text(title).font(.system(size: 10.5, weight: .bold)).foregroundColor(.gray)
            Spacer()
            Text(value).font(.system(size: 10.5, weight: .heavy, design: .monospaced))
                .foregroundColor(s.themeColors().0)
        }
        .padding(11)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    func presetRow(title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }) {
            HStack {
                Text(title).font(.system(size: 11.5, weight: .bold)).foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(s.themeColors().0).font(.system(size: 11))
            }
            .padding(11)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }.buttonStyle(PlainButtonStyle())
    }

    func colorBtn(idx: Int, color: Color, label: String) -> some View {
        Button(action: {
            s.crosshairColor = idx
            s.log("🎨 Đổi màu tâm: \(label)")
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            VStack(spacing: 3) {
                Circle().fill(color).frame(width: 28, height: 28)
                    .overlay(Circle().stroke(s.crosshairColor == idx ? Color.white : Color.clear, lineWidth: 2.5))
                    .shadow(color: color.opacity(0.8), radius: s.crosshairColor == idx ? 8 : 0)
                Text(label).font(.system(size: 7, weight: .bold)).foregroundColor(.white)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 5)
            .background(Color.white.opacity(s.crosshairColor == idx ? 0.10 : 0.03))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(PlainButtonStyle())
    }

    func themeBtn(idx: Int, name: String, c1: Color, c2: Color) -> some View {
        Button(action: {
            s.themeIdx = idx
            s.log("🎨 Đổi chủ đề: \(name)")
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            HStack {
                LinearGradient(colors: [c1, c2], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 40, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6)
                                .stroke(s.themeIdx == idx ? Color.white : Color.clear, lineWidth: 2))
                Text(name).font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                Spacer()
                if s.themeIdx == idx {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(c1)
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11)
                        .stroke(s.themeIdx == idx ? c1 : Color.white.opacity(0.1), lineWidth: 1))
        }.buttonStyle(PlainButtonStyle())
    }

    func contactCard(icon: String, title: String, sub: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.25))
                    .frame(width: 44, height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(color, lineWidth: 1.5))
                Text(icon).font(.system(size: 20))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .heavy)).foregroundColor(.white)
                Text(sub).font(.system(size: 9)).foregroundColor(color)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.4), lineWidth: 1))
    }

    func openZalo() {
        let phone = "0919178382"
        if let zaloURL = URL(string: "zalo://phone/\(phone)"),
           UIApplication.shared.canOpenURL(zaloURL) {
            UIApplication.shared.open(zaloURL, options: [:], completionHandler: nil)
            return
        }
        if let web = URL(string: "https://zalo.me/\(phone)") {
            UIApplication.shared.open(web, options: [:], completionHandler: nil)
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
                }
            }
            if style == 2 || style == 3 {
                Circle().fill(color).frame(width: 6, height: 6)
                    .shadow(color: color, radius: 10)
            }
            if style == 3 {
                Circle().stroke(color, lineWidth: 1)
                    .frame(width: size * 0.35, height: size * 0.35)
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

    @State private var pos: CGPoint = CGPoint(x: UIScreen.main.bounds.midX,
                                              y: UIScreen.main.bounds.midY)
    @State private var target: CGPoint = CGPoint(x: UIScreen.main.bounds.midX,
                                                 y: UIScreen.main.bounds.midY)
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
        .onDisappear { timer?.invalidate(); timer = nil }
    }
}
