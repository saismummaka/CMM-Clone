import Foundation
import AppKit

/// Persists security-scoped bookmarks so TCC-protected folders
/// (Downloads, Desktop, Documents) don't re-prompt every launch.
enum BookmarkStore {
    private static let defaultsKey = "CMMClone.bookmarks"

    /// Returns true if a usable bookmark exists (and starts access on the URL).
    /// If no bookmark exists, presents an NSOpenPanel asking the user to grant access.
    /// The returned URL has security-scoped access started; call `stopAccessing(url)` when done.
    @MainActor
    static func resolveOrPrompt(for path: String, promptMessage: String) -> URL? {
        // Try existing bookmark
        if let url = resolveExisting(for: path) {
            return url
        }
        // Prompt user
        let panel = NSOpenPanel()
        panel.message = promptMessage
        panel.prompt = "Grant Access"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: path)
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        do {
            let data = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            save(data, for: url.path)
            _ = url.startAccessingSecurityScopedResource()
            return url
        } catch {
            return nil
        }
    }

    /// Tries to resolve an already-saved bookmark without prompting.
    static func resolveExisting(for path: String) -> URL? {
        guard let all = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: Data] else { return nil }
        // Try exact path, then any saved parent
        let candidateKeys = [path] + all.keys.filter { path.hasPrefix($0) }
        for key in candidateKeys {
            guard let data = all[key] else { continue }
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                if isStale {
                    // Refresh bookmark
                    if let fresh = try? url.bookmarkData(
                        options: [.withSecurityScope],
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    ) {
                        save(fresh, for: url.path)
                    }
                }
                _ = url.startAccessingSecurityScopedResource()
                return url
            }
        }
        return nil
    }

    static func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }

    private static func save(_ data: Data, for path: String) {
        var all = (UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: Data]) ?? [:]
        all[path] = data
        UserDefaults.standard.set(all, forKey: defaultsKey)
    }

    /// Returns the paths that currently have a saved bookmark.
    static func grantedPaths() -> [String] {
        let all = (UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: Data]) ?? [:]
        return Array(all.keys)
    }

    /// Removes a saved bookmark.
    static func revoke(_ path: String) {
        var all = (UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: Data]) ?? [:]
        all.removeValue(forKey: path)
        UserDefaults.standard.set(all, forKey: defaultsKey)
    }
}
