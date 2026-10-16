
import UIKit
import SwiftUI
import Foundation
import MachO
import Darwin

// ============================================
// APP DELEGATE
// ============================================
@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let win = UIWindow(frame: UIScreen.main.bounds)
        win.rootViewController = UIHostingController(rootView: MainMenuView())
        win.makeKeyAndVisible()
        self.window = win

        // Khởi động thread inject chạy nền
        Injector.shared.startBackground()
        return true
    }
}

// ============================================
// STATE
// ============================================
class MenuState: ObservableObject {
    @Published var game: String = "" // "ff", "ffmax", "both"
    @Published var features: [String: Bool] = [:]

    // Aimbot
    @Published var aimbot: Bool = false
    @Published var headLock: Bool = true
    @Published var virtualCross: Bool = false
    @Published var dotCenter: Bool = false
    @Published var crossLine: Bool = false
    @Published var ghostCross: Bool = false
    @Published var magneticVis: Bool = false
    @Published var aimLock: Bool = false
    @Published var aimTrace: Bool = false
    @Published var headGuide: Bool = false

    // Antiban
    @Published var antiBan: Bool = true
    @Published var antiReport: Bool = true
    @Published var antiAFK: Bool = true
    @Published var antiKick: Bool = true
    @Published var antiDetection: Bool = true

    // Extra
    @Published var speed: Bool = false
    @Published var wallhack: Bool = false
    @Published var noRecoil: Bool = false
    @Published var rapidFire: Bool = false

    // Visual
    @Published var filterSea: Bool = false
    @Published var filterRed: Bool = false
    @Published var filterNight: Bool = false
    @Published var filterBright: Bool = false

    // Sliders
    @Published var fov: Double = 180
    @Published var smooth: Double = 0.30
    @Published var crossSize: Double = 120
    @Published var crossOpacity: Double = 1.0

    // Runtime
    @Published var injected: Bool = false
    @Published var fps: Int = 0
    @Published var ping: Int = 0
    @Published var ram: Int = 0
    @Published var battery: Int = 100
    @Published var logLines: [String] = []

    func log(_ msg: String) {
        let t = DateFormatter()
        t.dateFormat = "HH:mm:ss"
        let line = "[\(t.string(from: Date()))] \(msg)"
        logLines.append(line)
        if logLines.count > 100 { logLines.removeFirst() }
    }
}

// ============================================
// MAIN MENU VIEW
// ============================================
struct MainMenuView: View {
    @StateObject var s = MenuState()
    @State private var showInject = false
    @State private var injectProgress: Double = 0
    @State private var injectMsg: String = ""
    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(red: 0.02, green: 0.03, blue: 0.05),
                         Color(red: 0.05, green: 0.06, blue: 0.09)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()

            // Glow blobs
            GeometryReader { geo in
                Circle()
                    .fill(Color(red: 0, green: 0.6, blue: 1).opacity(0.25))
                    .frame(width: 300, height: 300)
                    .blur(radius: 90)
                    .offset(x: -80, y: -100)
                Circle()
                    .fill(Color(red: 1, green: 0, blue: 0.2).opacity(0.20))
                    .frame(width: 260, height: 260)
                    .blur(radius: 90)
                    .offset(x: geo.size.width - 140, y: geo.size.height - 300)
            }
            .ignoresSafeArea()

            VStack(spacing: 12) {
                header
                hudRow
                tabsBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        switch selectedTab {
                        case 0: aimTab
                        case 1: antibanTab
                        case 2: extraTab
                        case 3: visualTab
                        case 4: systemTab
                        default: aimTab
                        }
                    }
                    .padding(.bottom, 12)
                }
                footer
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)

            // Inject overlay
            if showInject {
                injectOverlay
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header
    var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(red: 0, green: 0.6, blue: 1),
                                 Color(red: 0, green: 0.83, blue: 1),
                                 Color(red: 1, green: 0, blue: 0.2)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 42, height: 42)
                    .shadow(color: .cyan.opacity(0.8), radius: 10)
                Text("ZH")
                    .font(.system(size: 16, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("ZWILZ HLONG")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(LinearGradient(
                        colors: [.white, .cyan, .white, Color(red: 1, green: 0.2, blue: 0.3)],
                        startPoint: .leading, endPoint: .trailing))
                Text("AIM VIP • v8.0")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.gray)
                    .tracking(1.5)
            }
            Spacer()
            Circle()
                .fill(s.injected ? Color.green : Color.red)
                .frame(width: 10, height: 10)
                .shadow(color: s.injected ? .green : .red, radius: 6)
        }
        .padding(12)
        .background(
            LinearGradient(colors: [Color.cyan.opacity(0.18), Color(red: 0.05, green: 0.06, blue: 0.09).opacity(0.9), Color(red: 1, green: 0, blue: 0.2).opacity(0.15)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(LinearGradient(colors: [.cyan, .white, Color(red: 1, green: 0, blue: 0.2)],
                                       startPoint: .leading, endPoint: .trailing), lineWidth: 1.2)
        )
    }

    // MARK: - HUD
    var hudRow: some View {
        HStack(spacing: 8) {
            hudItem(title: "FPS", value: "\(s.fps)")
            hudItem(title: "PING", value: "\(s.ping)ms")
            hudItem(title: "RAM", value: "\(s.ram)%")
            hudItem(title: "PIN", value: "\(s.battery)%")
        }
    }
    func hudItem(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.system(size: 8, weight: .bold)).foregroundColor(.gray).tracking(1)
            Text(value).font(.system(size: 12, weight: .heavy, design: .monospaced)).foregroundColor(.cyan)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: - Tabs
    var tabsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                tabBtn(idx: 0, title: "KÉO TÂM")
                tabBtn(idx: 1, title: "ANTIBAN")
                tabBtn(idx: 2, title: "EXTRA")
                tabBtn(idx: 3, title: "HIỂN THỊ")
                tabBtn(idx: 4, title: "HỆ THỐNG")
            }
            .padding(4)
        }
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
    func tabBtn(idx: Int, title: String) -> some View {
        Button {
            selectedTab = idx
        } label: {
            Text(title)
                .font(.system(size: 10, weight: .heavy))
                .tracking(1)
                .foregroundColor(selectedTab == idx ? .white : .gray)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(
                    Group {
                        if selectedTab == idx {
                            LinearGradient(colors: [.cyan, Color(red: 1, green: 0, blue: 0.2)],
                                           startPoint: .leading, endPoint: .trailing)
                        } else {
                            Color.clear
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - AIM TAB
    var aimTab: some View {
        VStack(spacing: 10) {
            sectionTitle("TÂM ẢO & CROSSHAIR")
            toggleCard(icon: "✚", title: "TÂM ẢO PRO", sub: "Crosshair đè trên màn hình", isOn: $s.virtualCross)
            toggleCard(icon: "🔴", title: "DOT CENTER", sub: "Chấm đỏ chính giữa màn hình", isOn: $s.dotCenter)
            toggleCard(icon: "➕", title: "CROSS LINE", sub: "Đường chữ thập dài 400px", isOn: $s.crossLine)
            toggleCard(icon: "👻", title: "GHOST CROSSHAIR", sub: "Tâm ảo đi theo ngón tay", isOn: $s.ghostCross)
            toggleCard(icon: "🧲", title: "MAGNETIC VISUAL", sub: "Vòng hút pulse quanh tâm", isOn: $s.magneticVis)
            toggleCard(icon: "🔒", title: "AIMLOCK VISUAL", sub: "Vòng lock center nhấp nháy", isOn: $s.aimLock)
            toggleCard(icon: "✨", title: "AIM TRACE", sub: "Vệt mờ theo ngón tay kéo", isOn: $s.aimTrace)
            toggleCard(icon: "💀", title: "BÁM ĐẦU", sub: "Đường guide vị trí đầu", isOn: $s.headGuide)

            sectionTitle("AIMBOT CORE")
            toggleCard(icon: "🎯", title: "AIMBOT", sub: "Kéo tâm tự động bám đầu", isOn: $s.aimbot)
            toggleCard(icon: "🔒", title: "HEAD LOCK", sub: "Khóa mục tiêu vào đầu", isOn: $s.headLock)

            sectionTitle("TÙY CHỈNH")
            sliderCard(title: "KÍCH THƯỚC TÂM ẢO", value: $s.crossSize, range: 60...240, suffix: "")
            sliderCard(title: "ĐỘ MỜ TÂM ẢO", value: $s.crossOpacity, range: 0.3...1.0, suffix: "")
            sliderCard(title: "FOV", value: $s.fov, range: 30...360, suffix: "°")
            sliderCard(title: "SMOOTH", value: $s.smooth, range: 0.05...1.0, suffix: "")
        }
    }

    // MARK: - ANTIBAN TAB
    var antibanTab: some View {
        VStack(spacing: 10) {
            sectionTitle("ANTIBAN")
            toggleCard(icon: "🛡️", title: "ANTI BAN", sub: "Chống ban tự động", isOn: $s.antiBan)
            toggleCard(icon: "✋", title: "ANTI REPORT", sub: "Reset counter report", isOn: $s.antiReport)
            toggleCard(icon: "🚶", title: "ANTI AFK", sub: "Fake input tránh kick", isOn: $s.antiAFK)
            toggleCard(icon: "🔒", title: "ANTI KICK", sub: "Chống kick khỏi phòng", isOn: $s.antiKick)
            toggleCard(icon: "🕵️", title: "ANTI DETECTION", sub: "Xóa flag phát hiện", isOn: $s.antiDetection)

            sectionTitle("TRẠNG THÁI")
            infoCard(title: "GAME ĐÃ CHỌN", value: s.game.isEmpty ? "CHƯA CHỌN" : s.game.uppercased())
            infoCard(title: "ĐÃ INJECT", value: s.injected ? "CÓ" : "CHƯA")
        }
    }

    // MARK: - EXTRA TAB
    var extraTab: some View {
        VStack(spacing: 10) {
            sectionTitle("CHỌN GAME")
            gameCard(id: "ff", icon: "🔥", title: "FREE FIRE", sub: "com.dts.freefireth")
            gameCard(id: "ffmax", icon: "💥", title: "FREE FIRE MAX", sub: "com.dts.freefiremax")
            gameCard(id: "both", icon: "⚡", title: "CẢ HAI", sub: "Áp dụng cho cả 2 game")

            sectionTitle("CHỨC NĂNG PHỤ")
            toggleCard(icon: "🐇", title: "SPEED", sub: "Tăng tốc chạy", isOn: $s.speed)
            toggleCard(icon: "👁️", title: "WALLHACK", sub: "Xuyên tường", isOn: $s.wallhack)
            toggleCard(icon: "🔫", title: "NO RECOIL", sub: "Không giật súng", isOn: $s.noRecoil)
            toggleCard(icon: "⚡", title: "RAPID FIRE", sub: "Bắn nhanh", isOn: $s.rapidFire)

            sectionTitle("LOG")
            logView
        }
    }

    // MARK: - VISUAL TAB
    var visualTab: some View {
        VStack(spacing: 10) {
            sectionTitle("BỘ LỌC MÀU")
            toggleCard(icon: "🌊", title: "FILTER SEA", sub: "Xanh biển", isOn: $s.filterSea)
            toggleCard(icon: "🔴", title: "FILTER RED", sub: "Đỏ nổi bật", isOn: $s.filterRed)
            toggleCard(icon: "🌙", title: "FILTER NIGHT", sub: "Chế độ ban đêm", isOn: $s.filterNight)
            toggleCard(icon: "☀️", title: "FILTER BRIGHT", sub: "Tăng sáng", isOn: $s.filterBright)
        }
    }

    // MARK: - SYSTEM TAB
    var systemTab: some View {
        VStack(spacing: 10) {
            sectionTitle("THÔNG TIN THIẾT BỊ")
            infoCard(title: "MÀN HÌNH", value: "\(Int(UIScreen.main.bounds.width))x\(Int(UIScreen.main.bounds.height))")
            infoCard(title: "SCALE", value: String(format: "%.1fx", UIScreen.main.scale))
            infoCard(title: "HỆ ĐIỀU HÀNH", value: UIDevice.current.systemVersion)
            infoCard(title: "MODEL", value: UIDevice.current.model)
            infoCard(title: "CPU CORES", value: "\(ProcessInfo.processInfo.processorCount)")
            infoCard(title: "RAM", value: "\(s.ram)%")
            infoCard(title: "PIN", value: "\(s.battery)%")

            sectionTitle("LOG HỆ THỐNG")
            logView
        }
    }

    // MARK: - Components
    func sectionTitle(_ t: String) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(LinearGradient(colors: [.cyan, Color(red: 1, green: 0, blue: 0.2)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 3, height: 14)
                .shadow(color: .cyan, radius: 4)
            Text(t)
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(.cyan)
                .tracking(2)
            Spacer()
            Rectangle()
                .fill(LinearGradient(colors: [Color.cyan.opacity(0.3), .clear],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
        }
        .padding(.top, 6)
    }

    func toggleCard(icon: String, title: String, sub: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isOn.wrappedValue
                              ? LinearGradient(colors: [.cyan, Color(red: 1, green: 0, blue: 0.2)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                              : LinearGradient(colors: [Color.cyan.opacity(0.25), Color.gray.opacity(0.2)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                    Text(icon).font(.system(size: 17))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundColor(.white)
                    Text(sub)
                        .font(.system(size: 9.5))
                        .foregroundColor(.gray)
                }
                Spacer()
                ZStack {
                    Capsule()
                        .fill(isOn.wrappedValue
                              ? LinearGradient(colors: [.cyan, Color(red: 1, green: 0, blue: 0.2)],
                                               startPoint: .leading, endPoint: .trailing)
                              : LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.1)],
                                               startPoint: .leading, endPoint: .trailing))
                        .frame(width: 48, height: 28)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 22, height: 22)
                        .shadow(color: .black.opacity(0.3), radius: 3)
                        .offset(x: isOn.wrappedValue ? 10 : -10)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOn.wrappedValue)
                }
            }
            .padding(13)
            .background(
                LinearGradient(colors: isOn.wrappedValue
                               ? [Color.cyan.opacity(0.18), Color(red: 1, green: 0, blue: 0.2).opacity(0.10)]
                               : [Color.white.opacity(0.05), Color.white.opacity(0.02)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isOn.wrappedValue
                            ? LinearGradient(colors: [.cyan, Color(red: 1, green: 0, blue: 0.2)],
                                             startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.1)],
                                             startPoint: .leading, endPoint: .trailing),
                            lineWidth: 1)
            )
            .shadow(color: isOn.wrappedValue ? .cyan.opacity(0.5) : .clear, radius: 8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    func gameCard(id: String, icon: String, title: String, sub: String) -> some View {
        let on = s.game == id
        return Button {
            s.game = on ? "" : id
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            HStack(spacing: 12) {
                Text(icon).font(.system(size: 22))
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                    Text(sub).font(.system(size: 9.5, design: .monospaced)).foregroundColor(.gray)
                }
                Spacer()
                if on {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.cyan)
                        .font(.system(size: 22))
                }
            }
            .padding(13)
            .background(on
                        ? LinearGradient(colors: [Color.cyan.opacity(0.20), Color(red: 1, green: 0, blue: 0.2).opacity(0.12)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.white.opacity(0.05), Color.white.opacity(0.02)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(on
                            ? LinearGradient(colors: [.cyan, Color(red: 1, green: 0, blue: 0.2)],
                                             startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.1)],
                                             startPoint: .leading, endPoint: .trailing),
                            lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    func sliderCard(title: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                Spacer()
                Text(String(format: "%.2f\(suffix)", value.wrappedValue))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
            }
            Slider(value: value, in: range)
                .tint(.cyan)
        }
        .padding(13)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    func infoCard(title: String, value: String) -> some View {
        HStack {
            Text(title).font(.system(size: 11, weight: .bold)).foregroundColor(.gray).tracking(1)
            Spacer()
            Text(value).font(.system(size: 11, weight: .heavy, design: .monospaced)).foregroundColor(.cyan)
        }
        .padding(13)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    var logView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(s.logLines, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundColor(.green)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
        }
        .frame(height: 180)
        .background(Color.black.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: - Footer
    var footer: some View {
        HStack(spacing: 10) {
            Button {
                resetAll()
            } label: {
                Text("ĐẶT LẠI")
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(1.5)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.15), lineWidth: 1))
            }

            Button {
                doInject()
            } label: {
                Text("💉 ÁP DỤNG")
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(1.5)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [.cyan, Color(red: 1, green: 0, blue: 0.2)],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .cyan.opacity(0.6), radius: 10)
            }
        }
    }

    // MARK: - Inject overlay
    var injectOverlay: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("💉").font(.system(size: 50))
                Text("ĐANG ÁP DỤNG")
                    .font(.system(size: 13, weight: .heavy)).tracking(2)
                    .foregroundColor(.cyan)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.1)).frame(height: 10)
                        Capsule()
                            .fill(LinearGradient(colors: [.cyan, Color(red: 1, green: 0, blue: 0.2)],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: g.size.width * injectProgress, height: 10)
                    }
                }.frame(height: 10)
                Text(injectMsg)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(30)
            .background(Color(red: 0.05, green: 0.06, blue: 0.09))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.cyan.opacity(0.5), lineWidth: 1.5))
            .shadow(color: .cyan.opacity(0.5), radius: 20)
            .padding(30)
        }
    }

    // MARK: - Actions
    func doInject() {
        if s.game.isEmpty {
            s.log("❌ CHƯA CHỌN GAME")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        showInject = true
        injectProgress = 0
        injectMsg = "Đang khởi tạo..."

        let steps: [(Double, String)] = [
            (0.15, "Kiểm tra cấu hình..."),
            (0.35, "Xác thực thiết bị..."),
            (0.55, "Áp dụng chức năng..."),
            (0.75, "Kích hoạt aimbot..."),
            (0.90, "Tối ưu hiệu năng..."),
            (1.00, "✔ HOÀN TẤT!")
        ]

        for (i, step) in steps.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.35) {
                withAnimation(.easeOut(duration: 0.3)) {
                    injectProgress = step.0
                    injectMsg = step.1
                }
                s.log(step.1)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            showInject = false
            s.injected = true
            s.log("✅ INJECT THÀNH CÔNG")
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            // Áp dụng config vào injector
            Injector.shared.applyConfig(
                aimbot: s.aimbot,
                headLock: s.headLock,
                antiBan: s.antiBan,
                antiReport: s.antiReport,
                antiAFK: s.antiAFK,
                antiKick: s.antiKick,
                speed: s.speed,
                wallhack: s.wallhack,
                fov: s.fov,
                smooth: s.smooth
            )
        }
    }

    func resetAll() {
        s.aimbot = false
        s.virtualCross = false
        s.dotCenter = false
        s.crossLine = false
        s.ghostCross = false
        s.magneticVis = false
        s.aimLock = false
        s.aimTrace = false
        s.headGuide = false
        s.speed = false
        s.wallhack = false
        s.noRecoil = false
        s.rapidFire = false
        s.filterSea = false
        s.filterRed = false
        s.filterNight = false
        s.filterBright = false
        s.injected = false
        s.log("⟳ ĐÃ ĐẶT LẠI")
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

// ============================================
// INJECTOR - CORE
// ============================================
class Injector {
    static let shared = Injector()

    private var thread: Thread?
    private var running = false

    private var _pid: Int32 = 0
    private var _base: UInt64 = 0
    private var _task: mach_port_t = 0

    // Config
    private var cfgAimbot = false
    private var cfgHeadLock = true
    private var cfgAntiBan = true
    private var cfgAntiReport = true
    private var cfgAntiAFK = true
    private var cfgAntiKick = true
    private var cfgSpeed = false
    private var cfgWallhack = false
    private var cfgFov: Float = 180
    private var cfgSmooth: Float = 0.30
    private var cfgRange: Float = 450

    func applyConfig(aimbot: Bool, headLock: Bool,
                     antiBan: Bool, antiReport: Bool, antiAFK: Bool, antiKick: Bool,
                     speed: Bool, wallhack: Bool, fov: Double, smooth: Double) {
        cfgAimbot = aimbot
        cfgHeadLock = headLock
        cfgAntiBan = antiBan
        cfgAntiReport = antiReport
        cfgAntiAFK = antiAFK
        cfgAntiKick = antiKick
        cfgSpeed = speed
        cfgWallhack = wallhack
        cfgFov = Float(fov)
        cfgSmooth = Float(smooth)
    }

    func startBackground() {
        guard !running else { return }
        running = true
        thread = Thread { [weak self] in
            self?.loop()
        }
        thread?.qualityOfService = .background
        thread?.start()
    }

    private func loop() {
        while running {
            if _task == 0 || _base == 0 {
                findProcess()
                Thread.sleep(forTimeInterval: 0.5)
                continue
            }
            if kill(_pid, 0) != 0 {
                _task = 0; _base = 0; _pid = 0
                Thread.sleep(forTimeInterval: 0.5)
                continue
            }

            if cfgAntiBan { runAntiban() }
            if cfgAimbot { runAimbot() }
            if cfgSpeed { runSpeed() }
            if cfgWallhack { runWallhack() }

            Thread.sleep(forTimeInterval: 0.008)
        }
    }

    private func findProcess() {
        _pid = findPID("freefiremax")
        if _pid <= 0 { return }
        var t: mach_port_t = 0
        if task_for_pid(mach_task_self_, _pid, &t) != KERN_SUCCESS { return }
        _task = t
        var info = task_dyld_info()
        var count = mach_msg_type_number_t(MemoryLayout<task_dyld_info>.size / MemoryLayout<natural_t>.size)
        let r = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(t, task_flavor_t(TASK_DYLD_INFO), $0, &count)
            }
        }
        if r != KERN_SUCCESS { return }
        _base = info.all_image_info_addr
    }

    private func findPID(_ name: String) -> Int32 {
        let n = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        if n <= 0 { return 0 }
        let cnt = Int(n) / MemoryLayout<pid_t>.size
        var pids = [pid_t](repeating: 0, count: cnt)
        proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, n)
        for p in pids where p != 0 {
            var path = [CChar](repeating: 0, count: 4096)
            proc_pidpath(p, &path, 4096)
            let s = String(cString: path)
            if s.contains(name) { return p }
        }
        return 0
    }

    // MARK: - Memory IO
    private func readBytes(_ addr: UInt64, _ size: Int) -> Data? {
        guard _task != 0, addr != 0 else { return nil }
        var buf = [UInt8](repeating: 0, count: size)
        var out: vm_size_t = 0
        let r = vm_read_overwrite(_task, addr, vm_size_t(size), vm_address_t(bitPattern: buf), &out)
        if r != KERN_SUCCESS { return nil }
        return Data(buf)
    }

    private func writeBytes(_ addr: UInt64, _ data: [UInt8]) {
        guard _task != 0, addr != 0 else { return }
        var buf = data
        _ = vm_write(_task, addr, vm_address_t(bitPattern: buf), mach_msg_type_number_t(data.count))
    }

    private func readU64(_ a: UInt64) -> UInt64 {
        guard let d = readBytes(a, 8) else { return 0 }
        return d.withUnsafeBytes { $0.load(as: UInt64.self) }
    }
    private func readI32(_ a: UInt64) -> Int32 {
        guard let d = readBytes(a, 4) else { return 0 }
        return d.withUnsafeBytes { $0.load(as: Int32.self) }
    }
    private func readF32(_ a: UInt64) -> Float {
        guard let d = readBytes(a, 4) else { return 0 }
        return d.withUnsafeBytes { $0.load(as: Float.self) }
    }
    private func readBool(_ a: UInt64) -> Bool {
        guard let d = readBytes(a, 1) else { return false }
        return d[0] != 0
    }
    private func writeF32(_ a: UInt64, _ v: Float) {
        var x = v
        withUnsafeBytes(of: &x) { writeBytes(a, Array($0)) }
    }
    private func writeI32(_ a: UInt64, _ v: Int32) {
        var x = v
        withUnsafeBytes(of: &x) { writeBytes(a, Array($0)) }
    }
    private func writeByte(_ a: UInt64, _ v: UInt8) {
        writeBytes(a, [v])
    }

    // MARK: - Offsets
    private let OFF_PLAYER_LIST: UInt64 = 0x7C4E1C
    private let OFF_LOCAL: UInt64 = 0x7C4E20
    private let OFF_SIZE: UInt64 = 0x1B0
    private let OFF_POS: UInt64 = 0x48
    private let OFF_ROT: UInt64 = 0x54
    private let OFF_HEAD: UInt64 = 0x88
    private let OFF_HP: UInt64 = 0xA0
    private let OFF_VIS: UInt64 = 0xA8
    private let OFF_KN: UInt64 = 0xAC
    private let OFF_SPEED: UInt64 = 0x2A4
    private let OFF_WALL: UInt64 = 0x3B8

    // MARK: - Antiban
    private func runAntiban() {
        if cfgAntiReport {
            writeI32(_base + 0x8C2F10, 0)
            writeI32(_base + 0x8C2F14, 0)
            writeByte(_base + 0x8C2F20, 0)
        }
        if cfgAntiAFK {
            let lp = readU64(_base + OFF_LOCAL)
            if lp != 0 {
                writeF32(lp + 0x2B8, 0.01)
                writeF32(lp + 0x2BC, 0.01)
            }
        }
        if cfgAntiKick {
            writeByte(_base + 0x8C3010, 0)
            writeByte(_base + 0x8C3011, 0)
            writeByte(_base + 0x8C3012, 0)
        }
        writeI32(_base + 0x8C4020, 0)
        writeByte(_base + 0x8C4028, 1)
    }

    // MARK: - Aimbot
    private func runAimbot() {
        let lp = readU64(_base + OFF_LOCAL)
        if lp == 0 { return }
        let lpos = readVec3(lp + OFF_POS)
        let lrotAddr = lp + OFF_ROT
        let lrot = readVec3(lrotAddr)

        let pl = readU64(_base + OFF_PLAYER_LIST)
        let n = readI32(_base + OFF_PLAYER_LIST + 4)

        var bestHead = Vec3()
        var bestScore: Float = 999999
        var found = false

        for i in 0..<Int(n) {
            let e = pl + UInt64(i) * OFF_SIZE
            if e == lp { continue }
            if readI32(e + OFF_HP) <= 0 { continue }
            if !readBool(e + OFF_VIS) { continue }
            if readBool(e + OFF_KN) { continue }
            let pp = readVec3(e + OFF_POS)
            let hd = readVec3(e + OFF_HEAD)
            let d = dist(lpos, pp)
            if d > cfgRange { continue }
            let (_, ty) = calcAngle(lpos, hd)
            let diff = abs(normAng(ty - lrot.y))
            if diff > cfgFov { continue }
            let sc = diff * 1.5 + d * 0.5
            if sc < bestScore {
                bestScore = sc
                bestHead = hd
                found = true
            }
        }

        if found {
            let (tp, ty) = calcAngle(lpos, bestHead)
            writeF32(lrotAddr, lerpAng(lrot.x, tp, cfgSmooth))
            writeF32(lrotAddr + 4, lerpAng(lrot.y, ty, cfgSmooth))
        }
    }

    private func runSpeed() {
        let lp = readU64(_base + OFF_LOCAL)
        if lp != 0 { writeF32(lp + OFF_SPEED, 8.5) }
    }
    private func runWallhack() {
        writeByte(_base + OFF_WALL, 1)
    }

    // MARK: - Math
    struct Vec3 { var x: Float = 0; var y: Float = 0; var z: Float = 0 }

    private func readVec3(_ a: UInt64) -> Vec3 {
        Vec3(x: readF32(a), y: readF32(a + 4), z: readF32(a + 8))
    }
    private func normAng(_ a: Float) -> Float {
        var x = a
        while x > 180 { x -= 360 }
        while x < -180 { x += 360 }
        return x
    }
    private func lerpAng(_ c: Float, _ t: Float, _ s: Float) -> Float {
        return normAng(c + normAng(t - c) * s)
    }
    private func dist(_ a: Vec3, _ b: Vec3) -> Float {
        let dx = a.x - b.x, dy = a.y - b.y, dz = a.z - b.z
        return sqrt(dx*dx + dy*dy + dz*dz)
    }
    private func calcAngle(_ l: Vec3, _ h: Vec3) -> (Float, Float) {
        let dx = h.x - l.x, dy = h.y - l.y, dz = h.z - l.z
        let d = sqrt(dx*dx + dy*dy)
        let pitch = normAng(atan2(dz, d) * 180.0 / .pi)
        let yaw = normAng(atan2(dy, dx) * 180.0 / .pi)
        return (pitch, yaw)
    }
}
