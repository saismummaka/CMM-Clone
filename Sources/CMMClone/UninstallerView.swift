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

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
