import AppKit
import Testing
@testable import NeoMD

@MainActor
struct MarkdownDocumentControllerMenuValidationTests {
    @Test func unrelatedSelectorsRetainSuperclassValidation() {
        let controller = MarkdownDocumentController()
        let superclass = NSDocumentController()
        for action in [#selector(NSDocumentController.openDocument(_:)),
                       #selector(NSDocumentController.saveAllDocuments(_:))] {
            let item = NSMenuItem(title: "Unrelated", action: action, keyEquivalent: "")
            #expect(controller.validateMenuItem(item) == superclass.validateMenuItem(item))
        }
    }

    @Test func freshControllerEnablesExistingFileNewWindow() {
        // Construction leaves history and reading-size preferences lazy. Do not
        // invoke actions or termination, which would initialize production history.
        let controller = MarkdownDocumentController()
        let item = NSMenuItem(title: "New Window…",
                              action: #selector(NSDocumentController.newDocument(_:)),
                              keyEquivalent: "n")
        item.target = controller
        #expect(controller.defaultType == nil)
        #expect(controller.validateMenuItem(item))
    }
}
