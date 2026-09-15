import XCTest
import UIKit

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

        app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Preset"].waitForExistence(timeout: 30),
                      "Panel header never appeared — the editor failed to load.")

        // Shoot the iPad in landscape. The panel lays its four blocks out
        // side by side at any width past 900 pt, which a 13" iPad clears
        // either way up — but portrait then centres that wide, short panel
        // in a 1376 pt window and half the screenshot is bare chassis.
        // Landscape is also how anyone holds an iPad with a guitar in their
        // lap.
        //
        // After `launch`, not before: set on a device with nothing in the
        // foreground, the orientation is reset by the app coming up, and
        // the first run of this came back portrait.
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .landscapeLeft
            sleep(2)
        }

        // Meters and LED lamps settle over the first frames; a beat here
        // keeps them from being caught mid-fade.
        sleep(2)
    }

    /// The panel as it opens. On an iPad that is the whole chain at once; on
    /// a phone it is Comp, Drive and the top of Wobble.
    func testPanel() {
        capture("01-panel")
    }

    /// The bottom of the chain — Space and the master strip. The panel is one
    /// scroll view, so on an iPad, where it already fits, this scrolls
    /// nowhere and the shot is a duplicate that the shell script drops.
    func testSpaceAndMaster() {
        // Drag up the rack ear, not the middle of the panel. The scroll view
        // is full width and the knobs inside it take a vertical drag as a
        // value change, so a centred swipe sets Tone to 8 kHz instead of
        // scrolling. The ear is 18 pt of empty chassis with nothing on it.
        let ear = CGVector(dx: 0.035, dy: 0.0)
        for _ in 0..<2 {
            app.coordinate(withNormalizedOffset: CGVector(dx: ear.dx, dy: 0.80))
                .press(forDuration: 0.05,
                       thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: ear.dx, dy: 0.20)))
            sleep(1)
        }
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
