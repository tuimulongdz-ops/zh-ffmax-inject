

import SwiftUI
import UIKit

struct InjectMenuView: View {
    @State private var aimbot = false
    @State private var headLock = true
    @State private var trigger = false
    @State private var antiBan = true
    @State private var antiReport = true
    @State private var antiAFK = true
    @State private var antiKick = true
    @State private var speed = false
    @State private var wallhack = false
    @State private var fov: Double = 180
    @State private var smooth: Double = 0.30
    @State private var expanded = true
    @State private var injected = false
    @State private var offset = CGSize.zero

    var body: some View {
        ZStack {
            if expanded {
                VStack(spacing: 10) {
                    header
                    Divider().background(Color.white.opacity(0.15))
                    group("AIMBOT", items: [
                        ("Aimbot", $aimbot, "scope"),
                        ("Head Lock", $headLock, "target"),
                        ("Trigger", $trigger, "bolt.fill"),
                    ])
                    group("ANTIBAN", items: [
                        ("Anti Ban", $antiBan, "shield.lefthalf.fill"),
                        ("Anti Report", $antiReport, "hand.raised.fill"),
                        ("Anti AFK", $antiAFK, "figure.walk"),
                        ("Anti Kick", $antiKick, "lock.shield.fill"),
                    ])
                    group("EXTRA", items: [
                        ("Speed", $speed, "hare.fill"),
                        ("Wallhack", $wallhack, "square.grid.3x3.fill"),
                    ])
                    sliders
                    injectButton
                }
                .padding(16)
                .frame(width: 290)
                .background(
                    ZStack {
                        VisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
                        LinearGradient(colors: [.cyan.opacity(0.30), .purple.opacity(0.30)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(LinearGradient(colors: [.cyan, .purple, .pink],
                                               startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                )
                .shadow(color: .cyan.opacity(0.5), radius: 18)
                .offset(offset)
                .gesture(DragGesture().onChanged { v in
                    offset = CGSize(width: offset.width + v.translation.width * 0.1,
                                    height: offset.height + v.translation.height * 0.1)
                })
            } else {
                Button(action: { withAnimation { expanded = true } }) {
                    Text("ZH")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 54, height: 54)
                        .background(Circle().fill(LinearGradient(colors: [.cyan, .purple],
                                                                 startPoint: .top, endPoint: .bottom)))
                        .shadow(color: .cyan, radius: 12)
                }
                .offset(offset)
                .gesture(DragGesture().onChanged { v in
                    offset = CGSize(width: offset.width + v.translation.width * 0.1,
                                    height: offset.height + v.translation.height * 0.1)
                })
            }
        }
    }

    var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Zwilz HLong")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(LinearGradient(colors: [.cyan, .pink],
                                                    startPoint: .leading, endPoint: .trailing))
                Text("FF MAX Inject v1.0")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            Circle()
                .fill(injected ? Color.green : Color.red)
                .frame(width: 10, height: 10)
                .shadow(color: injected ? .green : .red, radius: 6)
            Button(action: { withAnimation { expanded = false } }) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.system(size: 20))
            }
        }
    }

    func group(_ title: String, items: [(String, Binding<Bool>, String)]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.cyan.opacity(0.8))
                .padding(.leading, 4)
            ForEach(items.indices, id: \.self) { i in
                HStack {
                    Image(systemName: items[i].2)
                        .foregroundColor(items[i].1.wrappedValue ? .cyan : .white.opacity(0.4))
                        .frame(width: 20)
                    Text(items[i].0)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                    Toggle("", isOn: items[i].1)
                        .labelsHidden()
                        .tint(.cyan)
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    var sliders: some View {
        VStack(spacing: 6) {
            HStack {
                Text("FOV").font(.system(size: 11)).foregroundColor(.white.opacity(0.8))
                Spacer()
                Text("\(Int(fov))°").font(.system(size: 10)).foregroundColor(.cyan)
            }
            Slider(value: $fov, in: 30...360).tint(.cyan)
            HStack {
                Text("Smooth").font(.system(size: 11)).foregroundColor(.white.opacity(0.8))
                Spacer()
                Text(String(format: "%.2f", smooth)).font(.system(size: 10)).foregroundColor(.cyan)
            }
            Slider(value: $smooth, in: 0.05...1.0).tint(.cyan)
        }
        .padding(.horizontal, 10)
    }

    var injectButton: some View {
        Button(action: {
            injected.toggle()
            Injector.shared.inject(
                aimbot: aimbot, headLock: headLock, trigger: trigger,
                antiBan: antiBan, antiReport: antiReport,
                antiAFK: antiAFK, antiKick: antiKick,
                speed: speed, wallhack: wallhack,
                fov: fov, smooth: smooth
            )
        }) {
            Text(injected ? "STOP INJECT" : "INJECT NOW")
                .font(.system(size: 13, weight: .heavy))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: injected ? [.red, .orange] : [.cyan, .purple],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: (injected ? Color.red : Color.cyan).opacity(0.6), radius: 10)
        }
    }
}

struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    func makeUIView(context: Context) -> UIVisualEffectView { UIVisualEffectView(effect: effect) }
    func updateUIView(_ v: UIVisualEffectView, context: Context) { v.effect = effect }
}
