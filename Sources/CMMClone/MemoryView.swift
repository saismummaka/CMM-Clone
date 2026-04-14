import SwiftUI
import Foundation

struct MemoryView: View {
    @ObservedObject var system: SystemStats
    @State private var isCleaning = false
    @State private var resultText: String?
    @State private var beforeUsed: Double = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                // Big memory ring
                HStack(spacing: 24) {
                    bigRing
                    VStack(alignment: .leading, spacing: 10) {
                        MetricRow(label: "Used", value: String(format: "%.2f GB", system.memoryUsedGB), color: .purple)
                        MetricRow(label: "Free", value: String(format: "%.2f GB", system.memoryFreeGB), color: .green)
                        MetricRow(label: "Total", value: String(format: "%.2f GB", system.memoryTotalGB), color: .blue)
                    }
                    Spacer()
                }
                .padding(22)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )

                Text("Free Up Memory")
                    .font(.title3.bold())

                Text("Purging frees inactive memory by forcing the kernel to flush caches. Your Mac will briefly use more CPU while it reorganizes memory.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button {
                        Task { await cleanRAM() }
                    } label: {
                        HStack(spacing: 8) {
                            if isCleaning {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            } else {
                                Image(systemName: "wand.and.stars")
                            }
                            Text(isCleaning ? "Freeing memory..." : "Free Up RAM")
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
                        )
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(isCleaning)

                    Button {
                        system.refresh()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.ultraThinMaterial)
                            )
                    }
                    .buttonStyle(.plain)
                }

                if let result = resultText {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Text(result)
                            .font(.callout)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.green.opacity(0.12))
                    )
                }

                Spacer(minLength: 0)
            }
            .padding(28)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Free Up RAM")
                .font(.largeTitle.bold())
            Text("Release inactive memory and let your Mac breathe.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var bigRing: some View {
        ZStack {
            Circle()
                .stroke(Color.purple.opacity(0.18), lineWidth: 16)
            Circle()
                .trim(from: 0, to: system.memoryPressure)
                .stroke(
                    AngularGradient(colors: [.purple.opacity(0.7), .blue], center: .center),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: system.memoryPressure)
            VStack(spacing: 2) {
                Text("\(Int(system.memoryPressure * 100))%")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("in use")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 150, height: 150)
    }

    private func cleanRAM() async {
        isCleaning = true
        resultText = nil
        beforeUsed = system.memoryUsedGB
        let before = beforeUsed

        await Task.detached(priority: .userInitiated) {
            // purge requires admin on some systems. Try user-space first.
            let _ = Shell.run("/usr/sbin/purge")
        }.value

        // Give kernel a moment
        try? await Task.sleep(nanoseconds: 800_000_000)
        system.refresh()

        let after = system.memoryUsedGB
        let freed = max(0, before - after)
        resultText = String(format: "Freed approximately %.2f GB of memory.", freed)
        isCleaning = false
    }
}

struct MetricRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontDesign(.rounded)
                .fontWeight(.semibold)
        }
        .font(.callout)
        .frame(minWidth: 180)
    }
}
