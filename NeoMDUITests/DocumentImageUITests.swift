import AppKit
import Security
import XCTest

final class DocumentImageUITests: XCTestCase {
    private var directory: URL!
    private var originals: [URL: (Data, Date)] = [:]
    private var launchedApp: XCUIApplication?
    private var plainApplication: NSRunningApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("NeoMD-Images-\(UUID())")
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/fixtures/m1-12-images")
        try FileManager.default.copyItem(at: source, to: directory)
    }

    private func snapshot() throws {
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(atPath: directory.path))
        for case let path as String in enumerator {
            let url = directory.appendingPathComponent(path)
            if try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
                try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_700_000_000)], ofItemAtPath: url.path)
                originals[url] = (try Data(contentsOf: url), try XCTUnwrap(FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date))
            }
        }
    }

    override func tearDownWithError() throws {
        launchedApp?.terminate()
        if let plainApplication {
            plainApplication.terminate()
            let deadline = Date().addingTimeInterval(3)
            while !plainApplication.isTerminated && Date() < deadline {
                RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            }
            if !plainApplication.isTerminated { plainApplication.forceTerminate() }
        }
        chmod(directory.appendingPathComponent("img/private.png").path, 0o644)
        for (url, original) in originals {
            XCTAssertEqual(try Data(contentsOf: url), original.0)
            XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date, original.1)
        }
        try FileManager.default.removeItem(at: directory)
    }

    @MainActor private func open(_ name: String = "illustrated.md", appearance: String = "Light") async throws -> (XCUIApplication, XCUIElement) {
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment["NEOMD_UI_TEST_APPEARANCE"] = appearance
        app.launchEnvironment["NEOMD_UI_TEST_APPEARANCE_CHANNEL"] = "1"
        launchedApp = app
        app.launch()
        app.activate()
        let running = try XCTUnwrap(NSWorkspace.shared.frontmostApplication)
        XCTAssertEqual(running.bundleIdentifier, "io.neomd.NeoMD")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.allowsRunningApplicationSubstitution = false
        _ = try await NSWorkspace.shared.open([directory.appendingPathComponent(name)],
            withApplicationAt: try XCTUnwrap(running.bundleURL), configuration: configuration)
        let window = app.windows[name]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        return (app, window)
    }

    @MainActor private func wait(seconds: Double = 10, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        repeat {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        } while Date() < deadline
        return condition()
    }

    @MainActor private func image(_ label: String, in window: XCUIElement) -> XCUIElement {
        let element = window.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'MarkdownImageBlock-' AND label == %@", label)).firstMatch
        let scroll = window.scrollViews["DocumentReaderScrollView"]
        scroll.scroll(byDeltaX: 0, deltaY: 10000)
        for _ in 0..<24 {
            if element.exists && element.frame.minY >= scroll.frame.minY && element.frame.maxY < scroll.frame.maxY { return element }
            scroll.scroll(byDeltaX: 0, deltaY: -200)
        }
        XCTFail("Image not visible: \(label)\n\(window.debugDescription)")
        return element
    }

    @MainActor private func color(_ image: XCUIElement, window: XCUIElement) throws -> NSColor {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: window.screenshot().pngRepresentation))
        let x = Int((image.frame.midX - window.frame.minX) * CGFloat(bitmap.pixelsWide) / window.frame.width)
        let y = Int((image.frame.midY - window.frame.minY) * CGFloat(bitmap.pixelsHigh) / window.frame.height)
        return try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
    }

    /// Locate a single solid-colour rectangle inside this image's document-window region.
    /// AX supplies only the search region; expected bitmap dimensions come from fixtures.
    @MainActor private func footprint(_ image: XCUIElement, window: XCUIElement,
                                     matches: (NSColor) -> Bool) throws -> CGSize {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: window.screenshot().pngRepresentation))
        let scaleX = CGFloat(bitmap.pixelsWide) / window.frame.width
        let scaleY = CGFloat(bitmap.pixelsHigh) / window.frame.height
        let region = image.frame.intersection(window.frame)
        let left = max(0, Int((region.minX - window.frame.minX) * scaleX))
        let right = min(bitmap.pixelsWide, Int(ceil((region.maxX - window.frame.minX) * scaleX)))
        let top = max(0, Int((region.minY - window.frame.minY) * scaleY))
        let bottom = min(bitmap.pixelsHigh, Int(ceil((region.maxY - window.frame.minY) * scaleY)))
        var xs: [Int] = []
        var ys: [Int] = []
        for y in top..<bottom {
            for x in left..<right {
                if let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB), matches(color) {
                    xs.append(x)
                    ys.append(y)
                }
            }
        }
        if xs.isEmpty {
            record(window, "Missing footprint diagnostic")
            print("Footprint window=\(window.frame) image=\(image.frame) bitmap=\(bitmap.pixelsWide)x\(bitmap.pixelsHigh) region=\(left),\(top)-\(right),\(bottom) center=\(String(describing: bitmap.colorAt(x: (left + right) / 2, y: (top + bottom) / 2)?.usingColorSpace(.sRGB)))")
        }
        let minX = try XCTUnwrap(xs.min(), "Expected fixture colour missing")
        let maxX = try XCTUnwrap(xs.max())
        let minY = try XCTUnwrap(ys.min())
        let maxY = try XCTUnwrap(ys.max())
        XCTAssertEqual(xs.count, (maxX - minX + 1) * (maxY - minY + 1),
                       "Colour must form one unique solid rectangular footprint")
        return CGSize(width: CGFloat(maxX - minX + 1) / scaleX,
                      height: CGFloat(maxY - minY + 1) / scaleY)
    }

    @MainActor private func record(_ window: XCUIElement, _ name: String) {
        let attachment = XCTAttachment(screenshot: window.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor func testLocalImagesDisplayWithPreservedAspectRatioAndOriginalColors() async throws {
        try snapshot()
        for appearance in ["Light", "Dark"] {
            let (app, window) = try await open(appearance: appearance)
            let wide = image("Wide orange screenshot", in: window)
            XCTAssertTrue(wait { wide.value as? String == "Image displayed" })
            let width = min(760, window.scrollViews["DocumentReaderScrollView"].frame.width - 80)
            let wideSize = try footprint(wide, window: window) {
                $0.redComponent > 0.85 && $0.blueComponent < 0.35
            }
            XCTAssertEqual(wideSize.width, width, accuracy: 2)
            XCTAssertEqual(wideSize.height, width / 4, accuracy: 2)
            let orange = try color(wide, window: window)
            XCTAssertGreaterThan(orange.redComponent, 0.85)
            XCTAssertLessThan(orange.blueComponent, 0.35)
            record(window, "\(appearance) wide image")
            let small = image("Small green figure", in: window)
            XCTAssertTrue(wait { small.value as? String == "Image displayed" })
            let smallSize = try footprint(small, window: window) {
                $0.greenComponent > $0.redComponent + 0.2 && $0.greenComponent > $0.blueComponent + 0.2
            }
            XCTAssertEqual(smallSize.width, 64, accuracy: 2)
            XCTAssertEqual(smallSize.height, 32, accuracy: 2)
            let green = try color(small, window: window)
            XCTAssertGreaterThan(green.greenComponent, green.redComponent)
            for label in ["Magenta JPEG photo", "Two frame GIF", "Purple vector", "Quoted small figure"] {
                let item = image(label, in: window)
                XCTAssertTrue(wait { item.value as? String == "Image displayed" })
            }
            XCTAssertFalse(app.windows["SCRIPT EXECUTED"].exists)
            app.terminate()
        }
    }

    @MainActor func testLinkedBadgeRetainsActivationAndContextMenu() async throws {
        let url = directory.appendingPathComponent("illustrated.md")
        let source = """
        # Linked badge

        Before [![Small linked badge](img/small.png)](#unavailable-images) after.

        \((0..<25).map { "Filler paragraph \($0)." }.joined(separator: "\n\n"))

        ## Unavailable images

        Badge destination.
        """
        try source.write(to: url, atomically: true, encoding: .utf8)
        try snapshot()
        let (app, window) = try await open()
        let badge = window.links.matching(NSPredicate(format: "label CONTAINS %@", "Small linked badge")).firstMatch
        XCTAssertTrue(badge.waitForExistence(timeout: 3), window.debugDescription)
        guard badge.exists else { return }
        badge.rightClick()
        XCTAssertTrue(app.menuItems["#unavailable-images"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.menuItems["Open Link"].exists)
        XCTAssertTrue(app.menuItems["Copy Link"].exists)
        app.typeKey(.escape, modifierFlags: [])
        badge.click()
        XCTAssertTrue(wait { window.staticTexts["Unavailable images"].isHittable })
    }

    @MainActor func testNativeLinkedImagesWrapAndResizeWithoutUpscalingInBothThemes() async throws {
        let source = """
        [![Wide linked orange](img/wide.png)](#target)

        [![Small linked green](img/small.png)](#target) surrounding **bold** and *italic* prose that wraps without losing its links.

        ## Target
        """
        try source.write(to: directory.appendingPathComponent("illustrated.md"), atomically: true, encoding: .utf8)
        try snapshot()
        for appearance in ["Light", "Dark"] {
            let (app, window) = try await open(appearance: appearance)
            let wide = window.links.matching(NSPredicate(format: "label CONTAINS %@", "Wide linked orange, Image displayed")).firstMatch
            let small = window.links.matching(NSPredicate(format: "label CONTAINS %@", "Small linked green, Image displayed")).firstMatch
            XCTAssertTrue(wide.waitForExistence(timeout: 5))
            XCTAssertTrue(small.waitForExistence(timeout: 5))
            let before = try footprint(wide, window: window) { $0.redComponent > 0.85 && $0.blueComponent < 0.35 }
            XCTAssertEqual(before.height, before.width / 4, accuracy: 2)
            let width = window.frame.width
            let corner = window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1)).withOffset(CGVector(dx: -2, dy: -2))
            corner.press(forDuration: 0.1, thenDragTo: corner.withOffset(CGVector(dx: -220, dy: 0)))
            XCTAssertTrue(wait { window.frame.width < width - 100 })
            let after = try footprint(wide, window: window) { $0.redComponent > 0.85 && $0.blueComponent < 0.35 }
            XCTAssertLessThan(after.width, before.width - 100)
            XCTAssertEqual(after.height, after.width / 4, accuracy: 2)
            let natural = try footprint(small, window: window) { $0.greenComponent > $0.redComponent + 0.2 && $0.greenComponent > $0.blueComponent + 0.2 }
            XCTAssertEqual(natural.width, 64, accuracy: 2)
            XCTAssertEqual(natural.height, 32, accuracy: 2)
            record(window, "\(appearance) native linked image resized")
            app.terminate()
        }
    }

    @MainActor func testNativeLinkedImageParagraphKeepsProseSelectionReadOnly() async throws {
        let source = "Before [![Badge](img/small.png)](#target) after with **bold** prose.\n\n## Target"
        try source.write(to: directory.appendingPathComponent("illustrated.md"), atomically: true, encoding: .utf8)
        try snapshot()
        let (app, window) = try await open()
        let badge = window.links.matching(NSPredicate(format: "label CONTAINS %@", "Badge, Image displayed")).firstMatch
        XCTAssertTrue(badge.waitForExistence(timeout: 5))
        let pasteboard = NSPasteboard.general
        badge.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.8))
            .withOffset(CGVector(dx: -20, dy: 0)).doubleClick()
        try await ClipboardTestLease.copy(expected: "Before") {
            app.typeKey("c", modifierFlags: .command)
            XCTAssertTrue(pasteboard.string(forType: .string) == "Before", "Expected copied fixture prose")
            app.typeText("NO EDIT")
            app.typeKey("v", modifierFlags: .command)
            XCTAssertEqual(window.textViews.firstMatch.value as? String, "Before \u{FFFC} after with bold prose.")
        }
    }

    @MainActor func testLinkedHeadingRetainsProseAndKeyboardNavigationInBothThemes() async throws {
        let source = """
        # [![Heading badge](img/small.png)](#target) **Heading** and [prose link](#target)

        \((0..<25).map { "Heading filler \($0)." }.joined(separator: "\n\n"))

        ## Target

        HEADING TARGET
        """
        try source.write(to: directory.appendingPathComponent("illustrated.md"), atomically: true, encoding: .utf8)
        try snapshot()
        for appearance in ["Light", "Dark"] {
            let (app, window) = try await open(appearance: appearance)
            let badge = window.links.matching(NSPredicate(format: "label CONTAINS %@", "Heading badge, Image displayed")).firstMatch
            XCTAssertTrue(badge.waitForExistence(timeout: 5))
            XCTAssertTrue(window.descendants(matching: .any)
                .matching(NSPredicate(format: "value == %@", "\u{FFFC} Heading and prose link")).firstMatch.exists,
                window.debugDescription)
            let prose = window.links["prose link"]
            XCTAssertTrue(prose.exists)
            record(window, "\(appearance) native linked heading and prose")
            prose.click()
            XCTAssertTrue(wait { window.staticTexts["HEADING TARGET"].isHittable })
            window.scrollViews["DocumentReaderScrollView"].scroll(byDeltaX: 0, deltaY: 4000)
            XCTAssertTrue(wait { badge.isHittable })
            let group = window.groups["MarkdownLinkBlock-0"]
            var selected = false
            for _ in 0..<20 {
                app.typeKey(.tab, modifierFlags: [.option])
                app.typeKey(.rightArrow, modifierFlags: [])
                if group.label == "Link 2 of 2: prose link" { selected = true; break }
            }
            XCTAssertTrue(selected, window.debugDescription)
            app.typeKey(.leftArrow, modifierFlags: [])
            XCTAssertEqual(group.label, "Link 1 of 2: Heading badge")
            app.typeKey(.return, modifierFlags: [])
            XCTAssertTrue(wait { window.staticTexts["HEADING TARGET"].isHittable })
            app.terminate()
        }
    }

    @MainActor func testImageReaderRepeatedScrollingRetainsResponsiveContent() async throws {
        let source = """
        # Scroll probe

        Before [![Small linked badge](img/small.png)](#end) after.

        \((0..<25).map { "Filler paragraph \($0)." }.joined(separator: "\n\n"))

        ## End

        SCROLL END
        """
        try source.write(to: directory.appendingPathComponent("illustrated.md"), atomically: true, encoding: .utf8)
        try snapshot()
        let (_, window) = try await open()
        XCTAssertTrue(window.links.matching(NSPredicate(format: "label CONTAINS %@", "Image displayed"))
            .firstMatch.waitForExistence(timeout: 5))
        let scroll = window.scrollViews["DocumentReaderScrollView"]
        for _ in 0..<3 {
            scroll.scroll(byDeltaX: 0, deltaY: -150)
            scroll.scroll(byDeltaX: 0, deltaY: -150)
            scroll.scroll(byDeltaX: 0, deltaY: -2000)
            XCTAssertTrue(wait { window.staticTexts["SCROLL END"].isHittable })
            scroll.scroll(byDeltaX: 0, deltaY: 4000)
            XCTAssertTrue(wait { window.staticTexts["Scroll probe"].isHittable })
        }
    }

    @MainActor func testImagesRefitDuringActualWindowResize() async throws {
        try snapshot()
        let (_, window) = try await open()
        let wide = image("Wide orange screenshot", in: window)
        XCTAssertTrue(wait { wide.value as? String == "Image displayed" })
        let before = try footprint(wide, window: window) { $0.redComponent > 0.8 && $0.greenComponent < 0.7 }
        let originalWidth = window.frame.width
        let corner = window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1))
            .withOffset(CGVector(dx: -2, dy: -2))
        corner.press(forDuration: 0.1, thenDragTo: corner.withOffset(CGVector(dx: -220, dy: 0)))
        XCTAssertTrue(wait { window.frame.width < originalWidth - 100 })
        let resized = image("Wide orange screenshot", in: window)
        let after = try footprint(resized, window: window) { $0.redComponent > 0.8 && $0.greenComponent < 0.7 }
        XCTAssertLessThan(after.width, before.width - 100)
        XCTAssertEqual(after.height, after.width / 4, accuracy: 2)
        let small = image("Small green figure", in: window)
        let smallSize = try footprint(small, window: window) { $0.greenComponent > $0.redComponent }
        XCTAssertEqual(smallSize.width, 64, accuracy: 2)
        XCTAssertEqual(smallSize.height, 32, accuracy: 2)
        record(window, "Actual resized image footprints")
    }

    @MainActor func testPictureSourcesFollowAppearanceAndUpdateLive() async throws {
        try snapshot()
        let (_, window) = try await open()
        let label = "Shows a yellow sun square in light mode and a blue moon square in dark mode."
        let picture = image(label, in: window)
        XCTAssertTrue(wait { picture.value as? String == "Image displayed" })
        let originalFrame = picture.frame
        for appearance in ["Light", "Dark", "Light"] {
            DistributedNotificationCenter.default().postNotificationName(Notification.Name("io.neomd.uitest.setAppearance"),
                object: appearance, userInfo: nil, deliverImmediately: true)
            XCTAssertTrue(wait {
                guard let sample = try? self.color(picture, window: window) else { return false }
                return appearance == "Dark" ? sample.blueComponent > sample.redComponent : sample.redComponent > sample.blueComponent
            })
            XCTAssertEqual(picture.frame, originalFrame)
            record(window, "Live picture \(appearance)")
        }
        let fallback = image("Gray fallback in light mode, blue moon square in dark mode.", in: window)
        XCTAssertTrue(wait { fallback.value as? String == "Image displayed" })
        let gray = try color(fallback, window: window)
        // Authored fallback is blue-gray (#8c959f), not a neutral gray.
        XCTAssertGreaterThan(gray.blueComponent, gray.redComponent)
        XCTAssertLessThan(gray.blueComponent - gray.redComponent, 0.12)
        for appearance in ["Dark", "Light"] {
            DistributedNotificationCenter.default().postNotificationName(Notification.Name("io.neomd.uitest.setAppearance"),
                object: appearance, userInfo: nil, deliverImmediately: true)
            XCTAssertTrue(wait {
                guard let sample = try? self.color(fallback, window: window) else { return false }
                let difference = sample.blueComponent - sample.redComponent
                return appearance == "Dark" ? difference > 0.3 : difference > 0 && difference < 0.12
            })
            record(window, "Dark-only picture \(appearance)")
        }
    }

    @MainActor func testUnavailableImagesShowAlternativeTextAndOfferFolderAccess() async throws {
        try snapshot()
        chmod(directory.appendingPathComponent("img/private.png").path, 0)
        let (app, window) = try await open()
        for label in ["Missing diagram", "Corrupt diagram", "Private diagram"] {
            let item = image(label, in: window)
            XCTAssertTrue(wait { item.value as? String == "Image unavailable" })
        }
        let button = window.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'MarkdownImageAccessButton-'")).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertEqual(window.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'MarkdownImageAccessButton-'")).count, 1)
        button.click()
        let cancel = app.windows["open-panel"].buttons["CancelButton"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.click()
        XCTAssertFalse(app.alerts.firstMatch.exists)
        XCTAssertTrue(window.staticTexts["LOCAL END"].exists)
        record(window, "Unavailable alt text and explicit grant")
    }

    @MainActor func testPlainSandboxFolderGrantsAndArbitraryHostNetworking() async throws {
        let documentFolder = directory.appendingPathComponent("document")
        let unrelated = directory.appendingPathComponent("unrelated")
        try FileManager.default.createDirectory(at: documentFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: unrelated, withIntermediateDirectories: true)
        let file = documentFolder.appendingPathComponent("plain-\(UUID()).md")
        try """
        # Plain sandbox image reading

        ![Outside folder](../img/small.png)

        ![Arbitrary HTTP](http://httpbin.org/image/png)

        ![Arbitrary HTTPS](https://httpbin.org/image/png)

        PLAIN END
        """.write(to: file, atomically: true, encoding: .utf8)
        try snapshot()
        XCTAssertTrue(NSRunningApplication.runningApplications(withBundleIdentifier: "io.neomd.NeoMD").isEmpty,
                      "Plain launch requires no pre-existing NeoMD process; do not terminate unrelated apps.")
        let plainPath = try XCTUnwrap(ProcessInfo.processInfo.environment["NEOMD_PLAIN_APP_PATH"],
            "Provide TEST_RUNNER_NEOMD_PLAIN_APP_PATH pointing to a separate xcodebuild build (not test) artifact")
        let appURL = URL(fileURLWithPath: plainPath)
        try assertPlainSandboxSignature(appURL)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = ["-ApplePersistenceIgnoreState", "YES"]
        configuration.environment = [:]
        configuration.allowsRunningApplicationSubstitution = false
        let running = try await NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
        plainApplication = running
        let documentConfiguration = NSWorkspace.OpenConfiguration()
        documentConfiguration.allowsRunningApplicationSubstitution = false
        let documentApp = try await NSWorkspace.shared.open([file], withApplicationAt: appURL, configuration: documentConfiguration)
        XCTAssertEqual(documentApp.processIdentifier, running.processIdentifier)
        XCTAssertTrue(wait { running.isFinishedLaunching && !running.isTerminated })
        running.activate(options: [.activateAllWindows])
        XCTAssertTrue(wait { NSWorkspace.shared.frontmostApplication?.processIdentifier == running.processIdentifier })
        let app = XCUIApplication(url: try XCTUnwrap(running.bundleURL)) // Attach using the live process's canonical bundle URL.
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        let window = app.windows[file.lastPathComponent]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        let outside = image("Outside folder", in: window)
        XCTAssertTrue(wait { outside.value as? String == "Image unavailable" })
        for label in ["Arbitrary HTTP", "Arbitrary HTTPS"] {
            let remote = image(label, in: window)
            XCTAssertTrue(wait(seconds: 30) { remote.value as? String == "Image displayed" })
        }
        XCTAssertTrue(window.staticTexts["PLAIN END"].exists)
        let panel = app.windows["open-panel"]
        window.click()
        for step in 0..<6 {
            app.typeKey(.tab, modifierFlags: [.option])
            app.typeKey(.space, modifierFlags: [])
            if panel.exists { break }
            record(window, "Plain keyboard focus step \(step)")
        }
        XCTAssertTrue(panel.waitForExistence(timeout: 3), "Image folder-access button must be keyboard reachable")
        panel.buttons["CancelButton"].click()
        XCTAssertTrue(wait { outside.value as? String == "Image unavailable" })
        let access = window.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'MarkdownImageAccessButton-'" )).firstMatch
        access.click()
        try chooseFolder(unrelated, app: app)
        XCTAssertTrue(wait { outside.value as? String == "Image unavailable" })
        XCTAssertTrue(window.staticTexts["PLAIN END"].exists)
        access.click()
        try chooseFolder(directory.appendingPathComponent("img"), app: app)
        XCTAssertTrue(wait { outside.value as? String == "Image displayed" })
        XCTAssertFalse(access.exists)
        XCTAssertTrue(window.staticTexts["PLAIN END"].exists)
        record(window, "Plain sandbox HTTP HTTPS and explicit image-folder grant")
    }

    private func assertPlainSandboxSignature(_ app: URL) throws {
        var code: SecStaticCode?
        XCTAssertEqual(SecStaticCodeCreateWithPath(app as CFURL, [], &code), errSecSuccess)
        var information: CFDictionary?
        XCTAssertEqual(SecCodeCopySigningInformation(try XCTUnwrap(code), SecCSFlags(rawValue: kSecCSSigningInformation), &information), errSecSuccess)
        let info = try XCTUnwrap(information as? [String: Any])
        let entitlements = try XCTUnwrap(info[kSecCodeInfoEntitlementsDict as String] as? [String: Any])
        XCTAssertEqual(entitlements["com.apple.security.app-sandbox"] as? Bool, true)
        XCTAssertEqual(entitlements["com.apple.security.network.client"] as? Bool, true)
        XCTAssertEqual(entitlements["com.apple.security.files.user-selected.read-only"] as? Bool, true)
        XCTAssertFalse(entitlements.keys.contains { $0.hasPrefix("com.apple.security.temporary-exception") })
    }

    @MainActor private func chooseFolder(_ folder: URL, app: XCUIApplication) throws {
        let panel = app.windows["open-panel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 3))
        app.typeKey("g", modifierFlags: [.command, .shift])
        let go = panel.sheets["GoToWindow"]
        let field = go.textFields["PathTextField"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.click()
        app.typeKey("a", modifierFlags: [.command])
        app.typeText(folder.path + "/")
        XCTAssertTrue(wait { field.value as? String == folder.path + "/" })
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(wait { !go.exists })
        let allow = panel.buttons["OKButton"]
        XCTAssertTrue(wait { allow.exists && allow.isEnabled })
        allow.click()
        XCTAssertTrue(wait { !panel.exists })
    }

    @MainActor func testRemoteImagesLoadWithoutBlockingText() async throws {
        let server = try ImageHTTPServer()
        try await server.checkReady()
        let url = directory.appendingPathComponent("remote.md")
        let markdown = try String(contentsOf: url, encoding: .utf8)
            .replacingOccurrences(of: "http://127.0.0.1:PORT", with: server.endpoint.absoluteString)
            .replacingOccurrences(of: "https://127.0.0.1:PORT", with: server.endpoint.absoluteString.replacingOccurrences(of: "http:", with: "https:"))
        try markdown.write(to: url, atomically: true, encoding: .utf8)
        try snapshot()
        let (_, window) = try await open("remote.md")
        let scroll = window.scrollViews["DocumentReaderScrollView"]
        scroll.scroll(byDeltaX: 0, deltaY: -10000)
        XCTAssertTrue(window.staticTexts["REMOTE END"].waitForExistence(timeout: 2))
        let slow = image("Slow remote green", in: window)
        XCTAssertEqual(slow.value as? String, "Image loading")
        try await server.release()
        XCTAssertTrue(wait { slow.value as? String == "Image displayed" })
        for label in ["Refused remote", "Secure handshake failure", "Not an image response", "Not found response"] {
            let item = image(label, in: window)
            XCTAssertTrue(wait { item.value as? String == "Image unavailable" })
        }
        record(window, "Remote failures retain text")
    }
}

private struct ImageHTTPServer {
    let endpoint: URL

    init() throws {
        let value = try XCTUnwrap(ProcessInfo.processInfo.environment["NEOMD_IMAGE_ENDPOINT"],
                                 "Run via Scripts/image_test_controller.py; fixture endpoint is required")
        let url = try XCTUnwrap(URL(string: value))
        guard url.scheme == "http", url.host == "127.0.0.1", let port = url.port,
              port > 0, !url.lastPathComponent.isEmpty else {
            throw NSError(domain: "ImageFixtureEndpoint", code: 1)
        }
        endpoint = url
    }

    func checkReady() async throws { try await request("ready", method: "GET") }
    func release() async throws { try await request("release", method: "POST") }

    private func request(_ path: String, method: String) async throws {
        var request = URLRequest(url: endpoint.appendingPathComponent(path), timeoutInterval: 5)
        request.httpMethod = method
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              String(data: data, encoding: .utf8) == endpoint.lastPathComponent else {
            throw NSError(domain: "ImageFixtureHandshake", code: 1)
        }
    }
}
