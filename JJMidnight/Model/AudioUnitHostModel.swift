import SwiftUI
import AudioToolbox
import AVFAudio
import UIKit

@MainActor
@Observable
class AudioUnitHostModel {
    private let playEngine = SimplePlayEngine()
    var viewModel = AudioUnitViewModel()
    var isPlaying = false
    var isLoading = true
    var playbackError: String?
    var source: SimplePlayEngine.Source {
        get { playEngine.source }
        set { setSource(newValue) }
    }

    let type = "aufx"
    let subType = "Jjm1"
    let manufacturer = "Grov"

    private var didStart = false

    init() {}

    /// Load the AUv3 after the scene is active. The host engine is not created until Play.
    func start() async {
        guard !didStart else { return }
        didStart = true
        isLoading = true
        await waitUntilActive()

        let viewController = await playEngine.initComponent(
            type: type,
            subType: subType,
            manufacturer: manufacturer
        )

        isLoading = false
        viewModel = AudioUnitViewModel(
            showAudioControls: true,
            title: "jj-midnight",
            message: viewController == nil
                ? (playEngine.lastError ?? "Built-in effect failed to load.")
                : "Loaded",
            viewController: viewController
        )
        if viewController == nil {
            playbackError = viewModel.message
        }
        // Load the effect and leave it stopped — don't start the demo loop
        // (or the microphone) until the user taps Play.
    }

    private func waitUntilActive() async {
        if UIApplication.shared.applicationState == .active { return }
        for await _ in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) {
            break
        }
    }

    func startPlaying() async {
        playbackError = nil
        await playEngine.startPlaying()
        isPlaying = playEngine.isPlaying
        if !isPlaying {
            playbackError = playEngine.lastError ?? "Could not start audio. Check volume and the silent switch."
        }
    }

    func stopPlaying() {
        playEngine.stopPlaying()
        isPlaying = false
        playbackError = nil
    }

    func setSource(_ source: SimplePlayEngine.Source) {
        let wasPlaying = isPlaying
        playEngine.setSource(source)
        isPlaying = playEngine.isPlaying
        if wasPlaying {
            Task { await startPlaying() }
        }
    }
}
