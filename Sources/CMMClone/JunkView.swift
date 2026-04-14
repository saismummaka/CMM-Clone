import SwiftUI
import Foundation

struct JunkCategory: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: String
    let tint: Color
    let paths: [String]      // paths may be directories whose *contents* will be removed
    var sizeBytes: Int64 = 0
    var selected: Bool = true
}

@MainActor
final class JunkScanner: ObservableObject {
    @Published var categories: [JunkCategory] = []
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var lastCleanedBytes: Int64 = 0
    @Published var cleanedMessage: String?

    init() {
        categories = Self.defaultCategories()
    }

    static func defaultCategories() -> [JunkCategory] {
        let home = NSHomeDirectory()
        return [
            JunkCategory(
                name: "User Caches",
                icon: "tray.full",
                tint: .orange,
                paths: ["\(home)/Library/Caches"]
            ),
            JunkCategory(
                name: "User Logs",
                icon: "doc.text",
                tint: .yellow,
                paths: ["\(home)/Library/Logs"]
            ),
            JunkCategory(
                name: "Trash",
                icon: "trash",
                tint: .red,
                paths: ["\(home)/.Trash"]
            ),
            JunkCategory(
                name: "Xcode DerivedData",
                icon: "hammer",
                tint: .blue,
                paths: ["\(home)/Library/Developer/Xcode/DerivedData"]
            ),
            JunkCategory(
                name: "Xcode Archives",
                icon: "archivebox",
                tint: .indigo,
                paths: ["\(home)/Library/Developer/Xcode/Archives"]
            ),
            JunkCategory(
                name: "iOS Device Support",
                icon: "iphone",
                tint: .teal,
                paths: ["\(home)/Library/Developer/Xcode/iOS DeviceSupport"]
            ),
            JunkCategory(
                name: "Simulator Caches",
                icon: "cpu",
                tint: .mint,
                paths: ["\(home)/Library/Developer/CoreSimulator/Caches"]
            ),
            JunkCategory(
                name: "Downloads (older than 30 days)",
                icon: "arrow.down.circle",
                tint: .purple,
                paths: []    // handled specially
            ),
            JunkCategory(
                name: "Browser Caches",
                icon: "safari",
                tint: .cyan,
                paths: [
                    "\(home)/Library/Caches/com.apple.Safari",
                    "\(home)/Library/Caches/Google/Chrome",
                    "\(home)/Library/Caches/com.microsoft.edgemac",
                    "\(home)/Library/Caches/Firefox"
                ]
            )
        ]
    }

    var totalSelectedBytes: Int64 {
        categories.filter { $0.selected }.reduce(0) { $0 + $1.sizeBytes }
    }

    func scan() async {
        isScanning = true
        cleanedMessage = nil
        let baseCats = Self.defaultCategories()
        var updated = baseCats

        await withTaskGroup(of: (Int, Int64).self) { group in
            for (idx, cat) in baseCats.enumerated() {
                group.addTask {
                    let size: Int64
                    if cat.name.hasPrefix("Downloads") {
                        size = Self.sizeOfOldDownloads()
                    } else {
                        size = cat.paths.reduce(Int64(0)) { acc, p in
                            acc + Self.directorySize(p)
                        }
                    }
                    return (idx, size)
                }
            }
            for await (idx, size) in group {
                updated[idx].sizeBytes = size
            }
        }

        categories = updated
        isScanning = false
    }

    func clean() async {
        isCleaning = true
        cleanedMessage = nil
        var totalCleaned: Int64 = 0

        for cat in categories where cat.selected {
            if cat.name.hasPrefix("Downloads") {
                totalCleaned += Self.deleteOldDownloads()
            } else {
                for path in cat.paths {
                    totalCleaned += Self.deleteContents(of: path)
                }
            }
        }

        lastCleanedBytes = totalCleaned
        cleanedMessage = "Cleaned " + ByteFormatter.string(totalCleaned)
        await scan()
        isCleaning = false
    }

    // MARK: - Helpers

    nonisolated static func directorySize(_ path: String) -> Int64 {
        let url = URL(fileURLWithPath: path)
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return 0 }
        // Skip TCC-protected locations unless we already have access — probing them
        // would trigger a system permission prompt.
        if !fm.isReadableFile(atPath: path) { return 0 }
        var total: Int64 = 0
        if let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileAllocatedSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }  // silently skip inaccessible items
        ) {
            for case let fileURL as URL in enumerator {
                if let values = try? fileURL.resourceValues(forKeys: [.fileAllocatedSizeKey, .isRegularFileKey]),
                   values.isRegularFile == true {
                    total += Int64(values.fileAllocatedSize ?? 0)
                }
            }
        }
        return total
    }

    nonisolated static func deleteContents(of path: String) -> Int64 {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return 0 }
        var freed: Int64 = 0
        if let entries = try? fm.contentsOfDirectory(atPath: path) {
            for entry in entries {
                let full = (path as NSString).appendingPathComponent(entry)
                let size = directorySize(full) + (fileSize(full) ?? 0)
                do {
                    try fm.removeItem(atPath: full)
                    freed += size
                } catch {
                    // skip permission-denied items
                }
            }
        }
        return freed
    }

    nonisolated static func fileSize(_ path: String) -> Int64? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64 else { return nil }
        return size
    }

    nonisolated static func sizeOfOldDownloads() -> Int64 {
        let fm = FileManager.default
        let downloads = (NSHomeDirectory() as NSString).appendingPathComponent("Downloads")
        guard let entries = try? fm.contentsOfDirectory(atPath: downloads) else { return 0 }
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        var total: Int64 = 0
        for e in entries {
            let full = (downloads as NSString).appendingPathComponent(e)
            guard let attrs = try? fm.attributesOfItem(atPath: full),
                  let mod = attrs[.modificationDate] as? Date, mod < cutoff else { continue }
            total += directorySize(full) + (fileSize(full) ?? 0)
        }
        return total
    }

    nonisolated static func deleteOldDownloads() -> Int64 {
        let fm = FileManager.default
        let downloads = (NSHomeDirectory() as NSString).appendingPathComponent("Downloads")
        guard let entries = try? fm.contentsOfDirectory(atPath: downloads) else { return 0 }
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        var freed: Int64 = 0
        for e in entries {
            let full = (downloads as NSString).appendingPathComponent(e)
            guard let attrs = try? fm.attributesOfItem(atPath: full),
                  let mod = attrs[.modificationDate] as? Date, mod < cutoff else { continue }
            let size = directorySize(full) + (fileSize(full) ?? 0)
            do {
                try fm.removeItem(atPath: full)
                freed += size
            } catch {}
        }
        return freed
    }
}

struct JunkView: View {
    @StateObject private var scanner = JunkScanner()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                HStack(spacing: 16) {
                    Button(action: { Task { await scanner.scan() } }) {
                        HStack(spacing: 8) {
                            if scanner.isScanning {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "magnifyingglass")
                            }
                            Text(scanner.isScanning ? "Scanning..." : "Scan")
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                    }
                    .buttonStyle(.plain)

                    Button(action: { Task { await scanner.clean() } }) {
                        HStack(spacing: 8) {
                            if scanner.isCleaning {
                                ProgressView().controlSize(.small).tint(.white)
                            } else {
                                Image(systemName: "sparkles")
                            }
                            Text(scanner.isCleaning ? "Cleaning..." : "Clean Selected")
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing))
                        )
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(scanner.isCleaning || scanner.totalSelectedBytes == 0)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(ByteFormatter.string(scanner.totalSelectedBytes))
                            .font(.title3.bold())
                            .fontDesign(.rounded)
                            .foregroundStyle(LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing))
                    }
                }

                if let msg = scanner.cleanedMessage {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                        Text(msg)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.green.opacity(0.12))
                    )
                }

                LazyVStack(spacing: 10) {
                    ForEach(Array(scanner.categories.enumerated()), id: \.element.id) { idx, cat in
                        JunkRow(category: cat) { newSelected in
                            scanner.categories[idx].selected = newSelected
                        }
                    }
                }
            }
            .padding(28)
        }
        .task {
            await scanner.scan()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Clean Junk")
                .font(.largeTitle.bold())
            Text("Sweep caches, logs, Trash, and developer leftovers.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

struct JunkRow: View {
    let category: JunkCategory
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 14) {
            Toggle("", isOn: Binding(get: { category.selected }, set: { onToggle($0) }))
                .toggleStyle(.switch)
                .labelsHidden()

            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(category.tint.opacity(0.18))
                    .frame(width: 38, height: 38)
                Image(systemName: category.icon)
                    .foregroundStyle(category.tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(category.name).font(.headline)
                Text(category.paths.first ?? "Downloads folder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Text(ByteFormatter.string(category.sizeBytes))
                .font(.callout.bold())
                .fontDesign(.rounded)
                .foregroundStyle(category.sizeBytes > 0 ? .primary : .secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}

enum ByteFormatter {
    static func string(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useAll]
        return formatter.string(fromByteCount: bytes)
    }
}
