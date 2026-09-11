import AppKit

/// Native responder-chain commands; no writable or extra-view document actions.
final class NativeReaderMenus: NSObject, NSMenuDelegate {
    private let controller: MarkdownDocumentController
    private let recent = NSMenu(title: "Open Recent")

    init(controller: MarkdownDocumentController) {
        self.controller = controller
        super.init()
        let main = NSMenu()
        func menu(_ name: String) -> NSMenu {
            let item = NSMenuItem(title: name, action: nil, keyEquivalent: "")
            let submenu = NSMenu(title: name)
            item.submenu = submenu
            main.addItem(item)
            return submenu
        }
        let app = menu("NeoMD")
        add("About NeoMD", #selector(NSApplication.orderFrontStandardAboutPanel(_:)), to: app)
        let services = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        services.submenu = NSMenu(title: "Services")
        app.addItem(services)
        NSApp.servicesMenu = services.submenu
        app.addItem(.separator())
        add("Hide NeoMD", #selector(NSApplication.hide(_:)), key: "h", to: app)
        add("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), key: "h", modifiers: [.command, .option], to: app)
        add("Show All", #selector(NSApplication.unhideAllApplications(_:)), to: app)
        app.addItem(.separator())
        add("Quit NeoMD", #selector(NSApplication.terminate(_:)), key: "q", to: app)
        let file = menu("File")
        add("New Window…", #selector(NSDocumentController.newDocument(_:)), key: "n", target: controller, to: file)
        add("Open…", #selector(NSDocumentController.openDocument(_:)), key: "o", target: controller, to: file)
        let recents = NSMenuItem(title: "Open Recent", action: nil, keyEquivalent: "")
        recents.submenu = recent
        recent.delegate = self
        file.addItem(recents)
        file.addItem(.separator())
        add("Close", #selector(NSWindow.performClose(_:)), key: "w", to: file)
        add("Reveal in Finder", #selector(DocumentWindowController.revealDocument(_:)), to: file)
        let edit = menu("Edit")
        add("Copy", #selector(NSText.copy(_:)), key: "c", to: edit)
        add("Select All", #selector(NSText.selectAll(_:)), key: "a", to: edit)
        let window = menu("Window")
        add("Minimize", #selector(NSWindow.performMiniaturize(_:)), key: "m", to: window)
        add("Zoom", #selector(NSWindow.performZoom(_:)), to: window)
        add("Enter Full Screen", #selector(NSWindow.toggleFullScreen(_:)), key: "f", modifiers: [.command, .control], to: window)
        add("Bring All to Front", #selector(NSApplication.arrangeInFront(_:)), to: window)
        NSApp.windowsMenu = window
        NSApp.mainMenu = main
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        for url in controller.recentDocumentURLs {
            let item = NSMenuItem(title: url.path, action: #selector(MarkdownDocumentController.openRecent(_:)), keyEquivalent: "")
            item.representedObject = url
            item.target = controller
            menu.addItem(item)
        }
        menu.addItem(.separator())
        add("Clear Menu", #selector(NSDocumentController.clearRecentDocuments(_:)), target: controller, to: menu)
    }

    private func add(_ title: String, _ action: Selector, key: String = "",
                     modifiers: NSEvent.ModifierFlags = .command, target: AnyObject? = nil, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = target
        menu.addItem(item)
    }
}
