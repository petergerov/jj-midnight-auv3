import AudioToolbox
import Foundation
import Observation

/// State and actions behind the preset selector.
///
/// Follows the audio unit's `currentPreset` and `userPresets` through KVO,
/// so a preset chosen from a host's own menu shows here the same way as one
/// chosen from the dropdown.
@MainActor
@Observable
final class PresetBarViewModel {
    private(set) var title = "Default"
    private(set) var currentNumber: Int?
    private(set) var userPresets: [AUAudioUnitPreset] = []
    var errorMessage: String?

    private let audioUnit: JJMidnightAudioUnit?
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []

    init(audioUnit: JJMidnightAudioUnit?) {
        self.audioUnit = audioUnit
        reload()
        guard let audioUnit else { return }
        // KVO fires on whichever thread the host changed the preset from.
        observations = [
            audioUnit.observe(\.currentPreset) { [weak self] _, _ in
                DispatchQueue.main.async { self?.reload() }
            },
            audioUnit.observe(\.userPresets) { [weak self] _, _ in
                DispatchQueue.main.async { self?.reload() }
            },
        ]
    }

    /// Whether the knobs have moved since the preset loaded. Stored rather
    /// than computed so the dot redraws only when it flips, not on every
    /// check; `MainPanelViewModel`'s display loop calls `refreshDirty()`.
    private(set) var isDirty = false

    var isAvailable: Bool { audioUnit != nil }

    func refreshDirty() {
        let dirty = audioUnit?.isPresetDirty() ?? false
        if dirty != isDirty {
            isDirty = dirty
        }
    }

    /// Prefills Save As… with the current user preset's name, so saving
    /// over it is one tap; a factory preset starts the field empty.
    var suggestedSaveName: String {
        if let current = audioUnit?.currentPreset, current.number < 0 {
            return current.name
        }
        return ""
    }

    func reload() {
        userPresets = (audioUnit?.userPresets ?? []).sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        title = audioUnit?.currentPreset?.name ?? "Default"
        currentNumber = audioUnit?.currentPreset?.number
    }

    func selectFactory(_ number: Int) {
        audioUnit?.currentPreset = audioUnit?.factoryPresets?.first { $0.number == number }
        reload()
    }

    func select(_ preset: AUAudioUnitPreset) {
        audioUnit?.currentPreset = preset
        reload()
    }

    /// Returns whether the preset was saved, so the caller knows whether to
    /// close the name sheet or leave it up behind the error.
    func save(name: String) -> Bool {
        guard let audioUnit else {
            errorMessage = "Effect is not loaded."
            return false
        }
        do {
            try audioUnit.saveCurrentStateAsUserPreset(name: name)
            reload()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func rename(_ preset: AUAudioUnitPreset, to name: String) {
        do {
            try audioUnit?.renameUserPreset(preset, to: name)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ preset: AUAudioUnitPreset) {
        do {
            try audioUnit?.removeUserPreset(preset)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
