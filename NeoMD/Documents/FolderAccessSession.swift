import AppKit

/// Native user-selected read-only grants, held only until this app session ends.
@MainActor final class FolderAccessSession {
    private var leases: [URL] = []
    private var panelIsPresented = false

    func requestReadAccess(for target: URL, documentURL: URL) async -> Bool {
        // Do not stack permission panels when multiple windows activate links.
        guard !panelIsPresented else { return false }
        panelIsPresented = true
        defer { panelIsPresented = false }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = Self.suggestedFolder(for: target, documentURL: documentURL)
        panel.message = "Choose an enclosing folder to allow NeoMD read-only access until you quit the app."
        panel.prompt = "Allow Access"
        guard await panel.begin() == .OK, let folder = panel.url else { return false }
        if folder.startAccessingSecurityScopedResource() { leases.append(folder) }
        // Selecting an unrelated folder is not permission to dispatch the target.
        if case .readable = LocalFileAccessProbe.state(of: target) { return true }
        return false
    }

    static func suggestedFolder(for target: URL, documentURL: URL) -> URL {
        let parent = target.deletingLastPathComponent()
        if case .readable(isDirectory: true) = LocalFileAccessProbe.state(of: parent) { return parent }
        return documentURL.deletingLastPathComponent()
    }

    func endSession() {
        for url in leases { url.stopAccessingSecurityScopedResource() }
        leases.removeAll()
    }

    deinit {
        for url in leases { url.stopAccessingSecurityScopedResource() }
    }
}
