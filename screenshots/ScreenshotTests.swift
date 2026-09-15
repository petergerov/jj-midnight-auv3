import XCTest

/// Drives the container app and attaches one PNG per marketing shot.
///
/// This is an asset generator, not a test of behaviour — it asserts only
/// enough to fail loudly when the UI it aims at has moved. Run it through
/// `screenshots/make-screenshots.sh`, which pulls the attachments out of the
/// result bundle and writes them into `docs/images/` and `screenshots/store/`.
///
/// Everything it captures is the real app on a stock simulator: no device
/// frames, no composited backgrounds, no marketing text laid over the top.
/// App Review rejects screenshots showing UI the app does not have, and a
/// panel this heavily drawn is its own best advertisement anyway.
///
/// One shot per test method, deliberately. Each method gets a fresh launch
/// from `setUp`, so a knob nudged while scrolling in one shot cannot leak
/// into the next — the first draft did them all in one method and the panel
/// arrived at the preset shot with Tone already off its default and the
/// preset LED lit red.
final class ScreenshotTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false

        // Pin the orientation before launching. A simulator remembers how it
        // was left, so without this the shots depend on what the last run —
        // or the last person to use that simulator by hand — did to it, and
        // an iPad left in landscape silently produces a different frame size
        // from the one App Store Connect is expecting.
        XCUIDevice.shared.orientation = .portrait

        app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Preset"].waitForExistence(timeout: 30),
                      "Panel header never appeared — the editor failed to load.")

        // The iPad is shot in portrait, and that is not laziness.
        //
        // Landscape is the nicer crop — the panel lays its four blocks out
        // side by side past 900 pt, which a 13" iPad clears either way up,
        // and portrait leaves bare chassis above and below it. But rotating
        // from inside the test does not survive being photographed:
        // `XCUIDevice.shared.orientation = .landscapeLeft` flips the frame
        // immediately while the window keeps its portrait width for a while
        // afterwards, and `app.screenshot()` in that window returns a
        // landscape buffer holding a portrait window — black band down the
        // top, Space clipped off the right. Waiting on `app.frame` to report
        // landscape does not help, because the frame is the thing that
        // updates first.
        //
        // 2064x2752 is an accepted 13" App Store size, so portrait costs
        // nothing at the store; `make-site-images.sh` crops the chassis off
        // for the site, where the panel wants to be wide.

        // Meters and LED lamps settle over the first frames; a beat here
        // keeps them from being caught mid-fade.
        sleep(2)
    }

    /// The panel as it opens. On an iPad that is the whole chain at once; on
    /// a phone it is Comp, Drive and the top of Wobble.
    func testPanel() {
        capture("01-panel")
    }

    /// The bottom of the chain — Space and the master strip.
    ///
    /// Only on a device where the panel does not already fit. The panel is
    /// one scroll view that centres itself when the window is taller than it
    /// needs, so on an iPad this drag scrolls nowhere and the frame is the
    /// panel shot again. Whether that happens is a question about the device,
    /// so it is measured here rather than guessed from a screen size.
    func testSpaceAndMaster() {
        // Drag the rack ear, not the middle of the panel. The scroll view is
        // full width and the knobs inside it read a vertical drag as a value
        // change, so a centred swipe sets Tone to 10 kHz instead of scrolling.
        // The ear is 18 pt of empty chassis with nothing on it.
        let earX = 0.035
        let header = app.buttons["Preset"]
        let before = header.frame.origin.y

        for _ in 0..<2 {
            app.coordinate(withNormalizedOffset: CGVector(dx: earX, dy: 0.80))
                .press(forDuration: 0.05,
                       thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: earX, dy: 0.20)))
            sleep(1)
        }

        // The header rides the content, so if it has not moved, nothing has.
        // Shipping the duplicate would mean the same picture twice in the
        // App Store carousel.
        guard abs(header.frame.origin.y - before) > 20 else { return }
        capture("02-space-master")
    }

    /// The preset dropdown over the panel. The factory list is what a buyer
    /// scans first, and it names sounds rather than controls.
    func testPresets() {
        app.buttons["Preset"].tap()
        sleep(2)
        capture("03-presets")
    }

    // There is deliberately no paywall shot. Two reasons: the price on that
    // sheet is whatever the viewer's storefront charges, and a screenshot
    // freezes one currency onto a listing sold in every country; and the
    // sheet only prices itself once StoreKit has loaded the product, which
    // under `xcodebuild test` it does not — xcodegen writes the scheme's
    // .storekit reference into the Launch action only, so the run action
    // gets it and the test action does not, and the shot came back with the
    // button greyed out and "Unlock product not available yet." across it.
    // The trial terms belong in the description text, where they can be
    // edited without a new binary.

    /// `app.screenshot()`, not `XCUIScreen.main.screenshot()`. The screen
    /// hands back the physical framebuffer — on a rotated iPad that is
    /// portrait pixels with an EXIF orientation tag on top, which previews
    /// render correctly and App Store Connect, which reads the pixel
    /// dimensions, would read as the wrong size. The app's own screenshot is
    /// already in interface orientation with no tag to honour.
    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
