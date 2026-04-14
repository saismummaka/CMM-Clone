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
        NavigationSplitView {
            SidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
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
            .background(AuroraBackground())
        }
        .onAppear { system.start() }
    }
}

struct SidebarView: View {
    @Binding var selection: Module

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                VStack(alignment: .leading, spacing: 0) {
                    Text("CMM Clone")
                        .font(.headline)
                    Text("macOS Cleanup")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)

            VStack(spacing: 4) {
                ForEach(Module.allCases) { module in
                    SidebarButton(
                        module: module,
                        isSelected: selection == module
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            selection = module
                        }
                    }
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            Text("v1.0")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 10)
                .padding(.horizontal, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
    }
}

struct SidebarButton: View {
    let module: Module
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: module.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : module.tint)
                    .frame(width: 22)
                Text(module.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : .primary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isSelected
                            ? AnyShapeStyle(LinearGradient(colors: [module.tint, module.tint.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(isHovering ? Color.primary.opacity(0.08) : Color.clear)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
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
