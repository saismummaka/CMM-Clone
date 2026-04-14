import SwiftUI

enum Module: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case memory = "Free Up RAM"
    case junk = "Clean Junk"
    case uninstaller = "Uninstaller"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "sparkles"
        case .memory: return "memorychip"
        case .junk: return "trash"
        case .uninstaller: return "xmark.bin"
        }
    }

    var tint: Color {
        switch self {
        case .dashboard: return .blue
        case .memory: return .purple
        case .junk: return .orange
        case .uninstaller: return .pink
        }
    }
}

struct ContentView: View {
    @State private var selection: Module = .dashboard
    @StateObject private var system = SystemStats()

    var body: some View {
        ZStack {
            AuroraBackground()

            VStack(spacing: 0) {
                TopBarView(selection: $selection)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 10)

                Group {
                    switch selection {
                    case .dashboard:
                        DashboardView(system: system) { module in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                selection = module
                            }
                        }
                    case .memory:
                        MemoryView(system: system)
                    case .junk:
                        JunkView()
                    case .uninstaller:
                        UninstallerView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 780, minHeight: 560)
        .onAppear { system.start() }
    }
}

struct TopBarView: View {
    @Binding var selection: Module

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                Text("CMM Clone")
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.leading, 60)  // leave room for traffic lights
            .padding(.trailing, 16)

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                ForEach(Module.allCases) { module in
                    TopBarButton(
                        module: module,
                        isSelected: selection == module
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            selection = module
                        }
                    }
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )

            Spacer(minLength: 0)

            // Right-side spacer to keep center-alignment balanced
            Color.clear.frame(width: 120, height: 1)
        }
    }
}

struct TopBarButton: View {
    let module: Module
    let isSelected: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: module.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : module.tint)
                Text(module.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isSelected
                            ? AnyShapeStyle(LinearGradient(colors: [module.tint, module.tint.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(hovering ? Color.primary.opacity(0.08) : Color.clear)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct AuroraBackground: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            Circle()
                .fill(
                    LinearGradient(colors: [.blue.opacity(0.35), .purple.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 520, height: 520)
                .blur(radius: 120)
                .offset(x: animate ? -180 : -120, y: animate ? -200 : -160)

            Circle()
                .fill(
                    LinearGradient(colors: [.pink.opacity(0.25), .orange.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 480, height: 480)
                .blur(radius: 130)
                .offset(x: animate ? 220 : 180, y: animate ? 220 : 170)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
}
