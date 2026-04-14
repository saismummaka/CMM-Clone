import SwiftUI
import AppKit
import Foundation

struct InstalledApp: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bundleID: String
    let path: String          // .app path
    let version: String
    let sizeBytes: Int64
    let icon: NSImage?
    var selected: Bool = false
}

struct LeftoverItem: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let size: Int64
    var selected: Bool = true
}

@MainActor
final class AppScanner: ObservableObject {
    @Published var apps: [InstalledApp] = []
    @Published var isScanning = false
    @Published var filter: String = ""

    var filteredApps: [InstalledApp] {
        if filter.isEmpty { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(filter) || $0.bundleID.localizedCaseInsensitiveContains(filter) }
    }

    func scan() async {
        isScanning = true
        let roots = ["/Applications", (NSHomeDirectory() as NSString).appendingPathComponent("Applications")]
        var found: [InstalledApp] = []
        let fm = FileManager.default

        for root in roots {
            guard let entries = try? fm.contentsOfDirectory(atPath: root) else { continue }
            for entry in entries where entry.hasSuffix(".app") {
                let full = (root as NSString).appendingPathComponent(entry)
                if let app = Self.info(for: full) {
                    found.append(app)
                }
            }
        }

        // sort by name
        apps = found.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        isScanning = false
    }

    nonisolated static func info(for appPath: String) -> InstalledApp? {
        let bundle = Bundle(path: appPath)
        let name = (bundle?.infoDictionary?["CFBundleName"] as? String)
            ?? (bundle?.infoDictionary?["CFBundleDisplayName"] as? String)
            ?? ((appPath as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: ""))
        let bundleID = bundle?.bundleIdentifier ?? ""
        let version = (bundle?.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
        let size = JunkScanner.directorySize(appPath)
        let icon = NSWorkspace.shared.icon(forFile: appPath)
        icon.size = NSSize(width: 32, height: 32)
        return InstalledApp(name: name, bundleID: bundleID, path: appPath, version: version, sizeBytes: size, icon: icon)
    }

    // Find associated files for an app bundleID / name
    nonisolated static func leftoverPaths(for app: InstalledApp) -> [String] {
        let home = NSHomeDirectory()
        let id = app.bundleID
        let name = app.name
        var candidates: [String] = []

        let libraryScopes = [
            "\(home)/Library/Application Support",
            "\(home)/Library/Caches",
            "\(home)/Library/Preferences",
            "\(home)/Library/Containers",
            "\(home)/Library/Group Containers",
            "\(home)/Library/Logs",
            "\(home)/Library/Saved Application State",
            "\(home)/Library/HTTPStorages",
            "\(home)/Library/WebKit",
            "\(home)/Library/Cookies",
            "\(home)/Library/LaunchAgents",
            "/Library/Application Support",
            "/Library/Caches",
            "/Library/Preferences",
            "/Library/Logs",
            "/Library/LaunchAgents",
            "/Library/LaunchDaemons"
        ]

        let fm = FileManager.default
        for scope in libraryScopes {
            guard let entries = try? fm.contentsOfDirectory(atPath: scope) else { continue }
            for entry in entries {
                let lower = entry.lowercased()
                let nameL = name.lowercased()
                let idL = id.lowercased()
                if !idL.isEmpty && lower.contains(idL) {
                    candidates.append((scope as NSString).appendingPathComponent(entry))
                } else if lower.contains(nameL) && !nameL.isEmpty && nameL.count > 2 {
                    candidates.append((scope as NSString).appendingPathComponent(entry))
                }
            }
        }
        return candidates
    }
}

struct UninstallerView: View {
    @StateObject private var scanner = AppScanner()
    @State private var selectedApp: InstalledApp?
    @State private var leftovers: [LeftoverItem] = []
    @State private var scanningLeftovers = false
    @State private var uninstalling = false
    @State private var resultMessage: String?

    var body: some View {
        HSplitView {
            leftPane
                .frame(minWidth: 340, idealWidth: 380)
            rightPane
                .frame(minWidth: 420)
        }
        .task { await scanner.scan() }
    }

    private var leftPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Uninstaller")
                    .font(.largeTitle.bold())
                Text("Remove apps and their hidden leftovers.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter apps", text: $scanner.filter)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.ultraThinMaterial))
            .padding(.horizontal, 24)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(scanner.filteredApps) { app in
                        AppRow(
                            app: app,
                            isSelected: selectedApp?.id == app.id
                        ) {
                            selectedApp = app
                            Task { await findLeftovers(for: app) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            if scanner.isScanning {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Scanning applications...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 18)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.ultraThinMaterial)
    }

    private var rightPane: some View {
        ScrollView {
            if let app = selectedApp {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 16) {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 64, height: 64)
                        } else {
                            Image(systemName: "app")
                                .font(.system(size: 48))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.name).font(.title.bold())
                            Text(app.bundleID).font(.caption).foregroundStyle(.secondary)
                            Text("v\(app.version) · \(ByteFormatter.string(app.sizeBytes))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    HStack {
                        Text("Associated Files")
                            .font(.title3.bold())
                        Spacer()
                        Text(ByteFormatter.string(leftoversTotalBytes))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    if scanningLeftovers {
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("Finding related files...")
                                .foregroundStyle(.secondary)
                        }
                    } else if leftovers.isEmpty {
                        Text("No associated files found.")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(Array(leftovers.enumerated()), id: \.element.id) { idx, item in
                                LeftoverRow(item: item) { newSelected in
                                    leftovers[idx].selected = newSelected
                                }
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        Button(action: { Task { await uninstall(app: app) } }) {
                            HStack(spacing: 8) {
                                if uninstalling {
                                    ProgressView().controlSize(.small).tint(.white)
                                } else {
                                    Image(systemName: "xmark.bin")
                                }
                                Text(uninstalling ? "Uninstalling..." : "Uninstall Completely")
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(LinearGradient(colors: [.pink, .red], startPoint: .leading, endPoint: .trailing))
                            )
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .disabled(uninstalling)
                    }

                    if let msg = resultMessage {
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
                }
                .padding(28)
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "xmark.bin")
                        .font(.system(size: 56))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("Select an app to uninstall")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("You'll see its related files and caches before removing everything.")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var leftoversTotalBytes: Int64 {
        leftovers.reduce(0) { $0 + $1.size }
    }

    private func findLeftovers(for app: InstalledApp) async {
        scanningLeftovers = true
        resultMessage = nil
        leftovers = []
        let paths = AppScanner.leftoverPaths(for: app)
        var items: [LeftoverItem] = []
        for p in paths {
            let size = JunkScanner.directorySize(p) + (JunkScanner.fileSize(p) ?? 0)
            items.append(LeftoverItem(path: p, size: size))
        }
        leftovers = items.sorted { $0.size > $1.size }
        scanningLeftovers = false
    }

    private func uninstall(app: InstalledApp) async {
        uninstalling = true
        let fm = FileManager.default
        var freed: Int64 = 0

        // Delete associated files first
        for item in leftovers where item.selected {
            let size = item.size
            do {
                try fm.removeItem(atPath: item.path)
                freed += size
            } catch {
                // ignore permission denials
            }
        }

        // Delete the app bundle itself
        let appSize = app.sizeBytes
        do {
            try fm.removeItem(atPath: app.path)
            freed += appSize
        } catch {
            // trying Trash as fallback
            try? fm.trashItem(at: URL(fileURLWithPath: app.path), resultingItemURL: nil)
        }

        resultMessage = "Removed \(app.name) and \(ByteFormatter.string(freed)) of associated data."
        selectedApp = nil
        leftovers = []
        uninstalling = false
        await scanner.scan()
    }
}

struct AppRow: View {
    let app: InstalledApp
    let isSelected: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: "app").frame(width: 28, height: 28)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isSelected ? .white : .primary)
                    Text(ByteFormatter.string(app.sizeBytes))
                        .font(.caption2)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isSelected
                            ? AnyShapeStyle(LinearGradient(colors: [.pink, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(hovering ? Color.primary.opacity(0.06) : Color.clear)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct LeftoverRow: View {
    let item: LeftoverItem
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(get: { item.selected }, set: { onToggle($0) }))
                .toggleStyle(.switch)
                .labelsHidden()
            Image(systemName: "folder")
                .foregroundStyle(.secondary)
            Text(item.path)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Text(ByteFormatter.string(item.size))
                .font(.caption.bold())
                .fontDesign(.rounded)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}
