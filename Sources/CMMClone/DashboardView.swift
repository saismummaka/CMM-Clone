import SwiftUI

struct DashboardView: View {
    @ObservedObject var system: SystemStats
    let navigate: (Module) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                HStack(spacing: 18) {
                    StatRing(
                        title: "Memory",
                        value: system.memoryUsedGB,
                        total: system.memoryTotalGB,
                        unit: "GB",
                        color: .purple,
                        icon: "memorychip"
                    )
                    StatRing(
                        title: "Storage",
                        value: system.diskUsedGB,
                        total: system.diskTotalGB,
                        unit: "GB",
                        color: .blue,
                        icon: "internaldrive"
                    )
                }

                Text("Quick Actions")
                    .font(.title3.bold())
                    .padding(.top, 6)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                    ActionCard(
                        title: "Free Up RAM",
                        subtitle: "Purge inactive memory",
                        icon: "memorychip",
                        tint: .purple
                    ) { navigate(.memory) }

                    ActionCard(
                        title: "Clean Junk",
                        subtitle: "Caches, logs & temp files",
                        icon: "trash",
                        tint: .orange
                    ) { navigate(.junk) }

                    ActionCard(
                        title: "Uninstall Apps",
                        subtitle: "Remove apps completely",
                        icon: "xmark.bin",
                        tint: .pink
                    ) { navigate(.uninstaller) }

                    ActionCard(
                        title: "Refresh Stats",
                        subtitle: "Update system status",
                        icon: "arrow.clockwise",
                        tint: .blue
                    ) { system.refresh() }
                }
            }
            .padding(28)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hello, Sai")
                .font(.largeTitle.bold())
            Text("Your Mac is looking good. Here's a quick overview.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

struct StatRing: View {
    let title: String
    let value: Double
    let total: Double
    let unit: String
    let color: Color
    let icon: String

    var progress: Double {
        guard total > 0 else { return 0 }
        return min(1.0, value / total)
    }

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.18), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(colors: [color.opacity(0.7), color], center: .center),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: progress)
                VStack(spacing: 0) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Image(systemName: icon)
                        .font(.caption2)
                        .foregroundStyle(color)
                }
            }
            .frame(width: 90, height: 90)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(String(format: "%.1f / %.1f %@", value, total, unit))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(progress > 0.85 ? "High usage" : (progress > 0.6 ? "Moderate" : "Healthy"))
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(color.opacity(0.15))
                    )
                    .foregroundStyle(color)
            }
            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

struct ActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(colors: [tint, tint.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .foregroundStyle(.white)
                        .font(.system(size: 18, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .font(.footnote.weight(.semibold))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(hovering ? 0.15 : 0.05), lineWidth: 1)
            )
            .scaleEffect(hovering ? 1.015 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
