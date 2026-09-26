import Foundation
import Observation

/// Everything the panel does besides drawing: bypass, the licence gate and
/// the paywall, and the preset bar's model. Created by whoever hosts the
/// panel — the extension's view controller or the companion app's engine —
/// with the entitlement service passed in rather than reached for.
@MainActor
@Observable
final class MainPanelViewModel {
    let audioUnit: JJMidnightAudioUnit?
    let entitlement: EntitlementService
    let presets: PresetBarViewModel
    let meters: MeterViewModel

    var showPaywall = false

    var isBypassed: Bool {
        didSet { audioUnit?.shouldBypassEffect = isBypassed }
    }

    // The companion app puts its own trial banner in the chrome above the
    // panel, so a second copy inside the panel header just says the same
    // thing twice. A host has no such chrome, so there the panel keeps it —
    // it is the only way into the paywall from inside a DAW.
    let showsAccessBanner = Bundle.main.bundlePath.hasSuffix(".appex")

    init(audioUnit: JJMidnightAudioUnit?, entitlement: EntitlementService) {
        self.audioUnit = audioUnit
        self.entitlement = entitlement
        self.presets = PresetBarViewModel(audioUnit: audioUnit)
        self.meters = MeterViewModel(audioUnit: audioUnit)
        self.isBypassed = audioUnit?.shouldBypassEffect ?? false
    }

    /// The panel's one clock: meters every frame, the preset's edited dot
    /// four times a second. Runs for as long as the panel is on screen —
    /// the view starts it from `.task`, which cancels it on disappearance.
    func runDisplayLoop() async {
        var lastDirtyCheck = Date.distantPast
        while !Task.isCancelled {
            let now = Date()
            meters.tick(now: now)
            if now.timeIntervalSince(lastDirtyCheck) >= 0.25 {
                lastDirtyCheck = now
                presets.refreshDirty()
            }
            try? await Task.sleep(for: .milliseconds(16))
        }
    }

    var accessBannerState: AccessState? {
        guard showsAccessBanner, entitlement.accessState.bannerText != nil else { return nil }
        return entitlement.accessState
    }

    /// Re-read bypass and re-check the licence each time the panel appears:
    /// a host can keep the extension alive across the end of the trial, or
    /// change bypass while the panel was closed.
    func panelAppeared() async {
        isBypassed = audioUnit?.shouldBypassEffect ?? false
        await entitlement.refresh()
        syncLicense()
    }

    /// Push the licence state the entitlement service just cached into the
    /// kernel's render-thread gate.
    func syncLicense() {
        audioUnit?.applyLicenseFromStore()
    }
}
