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

@MainActor
final class AppScanner: ObservableObject {
    @Published var apps: [InstalledApp] = []
    @Published var isScanning = false
    @Published var filter: String = ""

    var filteredApps: [InstalledApp] {
        if filter.isEmpty { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(filter) || $0.bundleID.localizedCaseInsensitiveContains(filter) }
    }

    var selectedCount: Int {
        apps.filter { $0.selected }.count
    }

    var selectedSize: Int64 {
        apps.filter { $0.selected }.reduce(0) { $0 + $1.sizeBytes }
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

        apps = found.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        isScanning = false
    }

    func toggle(_ app: InstalledApp) {
        guard let idx = apps.firstIndex(where: { $0.id == app.id }) else { return }
        apps[idx].selected.toggle()
    }

    func clearSelection() {
        for i in apps.indices { apps[i].selected = false }
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
    @State private var uninstalling = false
    @State private var resultMessage: String?
    @State private var showingConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("Uninstaller")
                    .font(.largeTitle.bold())
                Text("Select apps to remove. Hidden caches, configs, and support files go with them.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 16)

            // Toolbar
            HStack(spacing: 10) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Filter apps", text: $scanner.filter)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.ultraThinMaterial))
                .frame(maxWidth: 280)

                Spacer()

                if scanner.selectedCount > 0 {
                    Button {
                        scanner.clearSelection()
                    } label: {
                        Text("Clear")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.ultraThinMaterial))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    showingConfirm = true
                } label: {
                    HStack(spacing: 6) {
                        if uninstalling {
                            ProgressView().controlSize(.small).tint(.white)
                        } else {
                            Image(systemName: "xmark.bin")
                        }
                        Text(uninstalling ? "Removing..." : "Uninstall \(scanner.selectedCount > 0 ? "(\(scanner.selectedCount))" : "")")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                scanner.selectedCount > 0
                                    ? AnyShapeStyle(LinearGradient(colors: [.pink, .red], startPoint: .leading, endPoint: .trailing))
                                    : AnyShapeStyle(Color.gray.opacity(0.3))
                            )
                    )
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(scanner.selectedCount == 0 || uninstalling)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 12)

            // Status row
            HStack {
                if scanner.isScanning {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Scanning applications...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("\(scanner.apps.count) apps · \(scanner.selectedCount) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if scanner.selectedCount > 0 {
                    Text(ByteFormatter.string(scanner.selectedSize))
                        .font(.caption.bold())
                        .fontDesign(.rounded)
                        .foregroundStyle(LinearGradient(colors: [.pink, .red], startPoint: .leading, endPoint: .trailing))
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 8)

            if let msg = resultMessage {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                    Text(msg)
                        .font(.callout)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.green.opacity(0.12)))
                .padding(.horizontal, 28)
                .padding(.bottom, 8)
            }

            // App list
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(scanner.filteredApps) { app in
                        AppCheckRow(app: app) {
                            scanner.toggle(app)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { await scanner.scan() }
        .alert("Uninstall \(scanner.selectedCount) app\(scanner.selectedCount == 1 ? "" : "s")?", isPresented: $showingConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Uninstall", role: .destructive) {
                Task { await uninstallSelected() }
            }
        } message: {
            Text("This will permanently remove the selected apps along with their caches, preferences, containers, and launch agents. This cannot be undone.")
        }
    }

    private func uninstallSelected() async {
        uninstalling = true
        let toRemove = scanner.apps.filter { $0.selected }
        var freed: Int64 = 0
        var removedNames: [String] = []
        let fm = FileManager.default

        for app in toRemove {
            // Find leftovers
            let paths = AppScanner.leftoverPaths(for: app)
            for p in paths {
                let size = JunkScanner.directorySize(p) + (JunkScanner.fileSize(p) ?? 0)
                do {
                    try fm.removeItem(atPath: p)
                    freed += size
                } catch { /* ignore */ }
            }
            // Remove .app
            let appSize = app.sizeBytes
            do {
                try fm.removeItem(atPath: app.path)
                freed += appSize
                removedNames.append(app.name)
            } catch {
                if (try? fm.trashItem(at: URL(fileURLWithPath: app.path), resultingItemURL: nil)) != nil {
                    freed += appSize
                    removedNames.append(app.name)
                }
            }
        }

        let count = removedNames.count
        resultMessage = "Removed \(count) app\(count == 1 ? "" : "s") · freed \(ByteFormatter.string(freed))"
        uninstalling = false
        await scanner.scan()
    }
}

struct AppCheckRow: View {
    let app: InstalledApp
    let onToggle: () -> Void

    @State private var hovering = false
    @State private var showingInfo = false

    var body: some View {
        HStack(spacing: 12) {
            // Custom checkbox (click on the row toggles)
            Button(action: onToggle) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(app.selected ? Color.clear : Color.primary.opacity(0.25), lineWidth: 1.5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(
                                    app.selected
                                        ? AnyShapeStyle(LinearGradient(colors: [.pink, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        : AnyShapeStyle(Color.clear)
                                )
                        )
                        .frame(width: 20, height: 20)
                    if app.selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            // Row body — clicking toggles selection
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: "app").frame(width: 32, height: 32)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(app.name)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                        Text(app.bundleID.isEmpty ? "—" : app.bundleID)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Text(ByteFormatter.string(app.sizeBytes))
                        .font(.callout)
                        .fontDesign(.rounded)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Info button — stops click propagation via its own Button
            Button {
                showingInfo.toggle()
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingInfo, arrowEdge: .trailing) {
                AppInfoPopover(app: app)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    app.selected
                        ? Color.pink.opacity(0.08)
                        : (hovering ? Color.primary.opacity(0.05) : Color.clear)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(app.selected ? Color.pink.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .onHover { hovering = $0 }
    }
}

struct AppInfoPopover: View {
    let app: InstalledApp
    @State private var paths: [(String, Int64)] = []
    @State private var loading = true

    var totalBytes: Int64 {
        app.sizeBytes + paths.reduce(0) { $0 + $1.1 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                if let icon = app.icon {
                    Image(nsImage: icon).resizable().frame(width: 36, height: 36)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name).font(.headline)
                    Text("Files that will be deleted")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    // App bundle itself
                    PathRow(path: app.path, size: app.sizeBytes, isPrimary: true)

                    if loading {
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("Finding related files...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    } else if paths.isEmpty {
                        Text("No additional support files found.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(Array(paths.enumerated()), id: \.offset) { _, entry in
                            PathRow(path: entry.0, size: entry.1, isPrimary: false)
                        }
                    }
                }
            }
            .frame(maxHeight: 280)

            Divider()

            HStack {
                Text("Total").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(ByteFormatter.string(totalBytes))
                    .font(.callout.bold())
                    .fontDesign(.rounded)
            }
        }
        .padding(14)
        .frame(width: 440)
        .task {
            await load()
        }
    }

    private func load() async {
        loading = true
        let found = await Task.detached(priority: .userInitiated) { () -> [(String, Int64)] in
            let p = AppScanner.leftoverPaths(for: app)
            return p.map { path in
                let size = JunkScanner.directorySize(path) + (JunkScanner.fileSize(path) ?? 0)
                return (path, size)
            }.sorted { $0.1 > $1.1 }
        }.value
        paths = found
        loading = false
    }
}

struct PathRow: View {
    let path: String
    let size: Int64
    let isPrimary: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isPrimary ? "app.fill" : "folder")
                .foregroundStyle(isPrimary ? .pink : .secondary)
                .frame(width: 16)
            Text(path)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Text(ByteFormatter.string(size))
                .font(.caption.bold())
                .fontDesign(.rounded)
                .foregroundStyle(.secondary)
        }
    }
}
