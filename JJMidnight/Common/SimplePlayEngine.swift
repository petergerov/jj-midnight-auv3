import Foundation
import AVFoundation
import CoreAudioKit
import AudioToolbox
import SwiftUI
import os
@preconcurrency import AVFAudio

private let log = Logger(subsystem: "com.gerov.jjmidnight", category: "PlayEngine")

@MainActor
@Observable
public class SimplePlayEngine {
    enum Source: String, CaseIterable, Identifiable {
        // Segmented-picker labels. Four segments on a phone leave about 80 pt
        // each, so the guitar parts are bare numbers — "Guitar 1" truncates at
        // that width. `spokenName` carries what the numbers drop, so nothing
        // is lost to a screen reader.
        case loop1 = "1"
        case loop2 = "2"
        case loop3 = "3"
        case microphone = "Mic"
        var id: String { rawValue }

        /// Bundle resource holding this source's audio, or nil for live input.
        var resourceName: String? {
            switch self {
            case .loop1: return "loop_1"
            case .loop2: return "loop_2"
            case .loop3: return "loop_3"
            case .microphone: return nil
            }
        }

        var isLoop: Bool { resourceName != nil }

        /// What the visual label would say if there were room for it.
        var spokenName: String {
            switch self {
            case .loop1: return "Guitar part 1"
            case .loop2: return "Guitar part 2"
            case .loop3: return "Guitar part 3"
            case .microphone: return "Microphone"
            }
        }
    }

    private(set) var avAudioUnit: AVAudioUnit?
    /// Created only when the user hits Play, after the audio session is active.
    private var engine: AVAudioEngine?
    private let player = AVAudioPlayerNode()
    /// Decoded demo parts, keyed by bundle resource name. Filled on demand
    /// rather than at init: decoding every part up front would cost a dozen
    /// megabytes of PCM for audio the user may never select.
    private var demoBuffers: [String: AVAudioPCMBuffer] = [:]
    private var graphFormat: AVAudioFormat
    private(set) var isPlaying = false
    private(set) var lastError: String?
    var source: Source = .loop1

    public init() {
        // Preload the first part only, so `graphFormat` starts out matching
        // real audio and the first tap on Play does not have to decode.
        graphFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        if let buffer = loadDemoBuffer(for: .loop1) {
            graphFormat = buffer.format
        } else {
            log.error("Demo part missing: loop_1.mp3 is not in the app bundle")
        }
    }

    /// Returns the decoded buffer for a loop source, loading and caching it
    /// the first time it is asked for.
    private func demoBuffer(for source: Source) -> AVAudioPCMBuffer? {
        guard let name = source.resourceName else { return nil }
        if let cached = demoBuffers[name] { return cached }
        return loadDemoBuffer(for: source)
    }

    @discardableResult
    private func loadDemoBuffer(for source: Source) -> AVAudioPCMBuffer? {
        guard let name = source.resourceName,
              let buffer = Self.readAudioResource(named: name)
        else { return nil }
        demoBuffers[name] = buffer
        return buffer
    }

    func initComponent(type: String, subType: String, manufacturer: String) async -> ViewController? {
        reset()
        configureSession(for: source)

        // Do not instantiate aufx/Jjm1/Grov here. That is the AUv3 appex; loading your
        // own extension from the containing app fails on device even when GarageBand works.
        // The standalone player uses a private in-process subclass instead.
        var local = AudioComponentDescription()
        local.componentType = kAudioUnitType_Effect
        local.componentSubType = "JjtH".fourCharCode ?? 0
        local.componentManufacturer = "Grov".fourCharCode ?? 0
        local.componentFlags = 0
        local.componentFlagsMask = 0

        AUAudioUnit.registerSubclass(
            JJMidnightAudioUnit.self,
            as: local,
            name: "jj-midnight standalone",
            version: 1
        )

        do {
            let audioUnit = try await AVAudioUnit.instantiate(with: local, options: [])
            return finishLoadInProcess(audioUnit)
        } catch {
            lastError = "Could not start the built-in effect: \(error.localizedDescription)"
            log.error("Standalone AU failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func finishLoadInProcess(_ audioUnit: AVAudioUnit) -> ViewController? {
        guard let unit = audioUnit.auAudioUnit as? JJMidnightAudioUnit else {
            lastError = "Built-in effect did not load in-process."
            return nil
        }
        avAudioUnit = audioUnit
        lastError = nil
        if unit.parameterTree == nil {
            unit.setupParameterTree(JJMidnightParameterSpecs.createAUParameterTree())
        } else {
            unit.applyLicenseFromStore()
        }
        guard let tree = unit.observableParameterTree else {
            lastError = "Effect parameters failed to load."
            return nil
        }
        let host = HostingController(rootView: JJMidnightMainView(parameterTree: tree, audioUnit: unit))
        host.view.backgroundColor = .black
        return host
    }

    func startPlaying() async {
        lastError = nil
        guard let avAudioUnit else {
            lastError = "The effect is not loaded yet."
            return
        }
        guard !isPlaying else { return }

        if source == .microphone {
            let granted = await AVAudioApplication.requestRecordPermission()
            guard granted else {
                lastError = "Microphone access is off. Pick a guitar part, or allow the mic in Settings."
                return
            }
        }

        // Resolve and decode before building the graph: wireGraph connects the
        // player node at `graphFormat`, so the format has to match the part we
        // are about to schedule. The two parts happen to share a format today,
        // but nothing guarantees a third one would.
        var partBuffer: AVAudioPCMBuffer?
        if source.isLoop {
            guard let buffer = demoBuffer(for: source) else {
                lastError = "Demo audio is missing."
                return
            }
            partBuffer = buffer
            graphFormat = buffer.format
        }

        guard let engine = makeEngine() else {
            lastError = lastError ?? "Could not start the audio engine."
            return
        }
        guard wireGraph(engine: engine, avAudioUnit: avAudioUnit) else {
            lastError = lastError ?? "Could not connect the effect to audio."
            teardownEngine()
            return
        }
        guard startEngine(engine) else { return }

        switch source {
        case .loop1, .loop2, .loop3:
            player.stop()
            if let demoBuffer = partBuffer {
                // Non-async overload: for a looping buffer the completion callback
                // only fires once looping stops, so `await`-ing it here would leave
                // this call suspended until the next stop/play, and its `player.play()`
                // below would then fire later as a stale continuation racing whatever
                // engine is current at that point (crashes if the node has since been
                // detached). Fire-and-forget scheduling avoids that entirely.
                player.scheduleBuffer(demoBuffer, at: nil, options: .loops, completionHandler: nil)
            } else {
                lastError = "Demo audio is missing."
                teardownEngine()
                return
            }
            player.play()
        case .microphone:
            break
        }
        isPlaying = true
    }

    func stopPlaying() {
        guard isPlaying else { return }
        teardownEngine()
    }

    func setSource(_ newSource: Source) {
        if isPlaying { teardownEngine() }
        source = newSource
    }

    func reset() {
        teardownEngine()
        avAudioUnit = nil
    }

    /// Session first, then force-create `outputNode` before mixer/attach/prepare.
    private func makeEngine() -> AVAudioEngine? {
        teardownEngine()
        configureSession(for: source)

        let engine = AVAudioEngine()
        // Accessing outputNode creates the hardware I/O unit. mainMixerNode / prepare()
        // will assert if this is skipped (AVAudioEngineGraph Initialize).
        _ = engine.outputNode
        self.engine = engine
        return engine
    }

    private func wireGraph(engine: AVAudioEngine, avAudioUnit: AVAudioUnit) -> Bool {
        let output = engine.outputNode
        let mixer = engine.mainMixerNode

        if !engine.attachedNodes.contains(player) {
            engine.attach(player)
        }
        if !engine.attachedNodes.contains(avAudioUnit) {
            engine.attach(avAudioUnit)
        }

        engine.disconnectNodeInput(mixer)
        engine.disconnectNodeOutput(player)
        engine.disconnectNodeOutput(avAudioUnit)

        let hw = output.outputFormat(forBus: 0)
        let ioFormat: AVAudioFormat
        if hw.sampleRate > 0, hw.channelCount > 0 {
            ioFormat = hw
        } else {
            ioFormat = graphFormat
        }

        switch source {
        case .loop1, .loop2, .loop3:
            engine.connect(player, to: avAudioUnit, format: graphFormat)
            engine.connect(avAudioUnit, to: mixer, format: graphFormat)
            engine.connect(mixer, to: output, format: ioFormat)
        case .microphone:
            let input = engine.inputNode
            let inputFormat = input.outputFormat(forBus: 0)
            guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
                lastError = "Microphone is not ready. Unplug accessories and try again."
                log.error("Microphone format is not ready")
                return false
            }
            engine.connect(input, to: avAudioUnit, format: inputFormat)
            engine.connect(avAudioUnit, to: mixer, format: inputFormat)
            engine.connect(mixer, to: output, format: ioFormat)
        }
        return true
    }

    private func startEngine(_ engine: AVAudioEngine) -> Bool {
        var exception: NSError?
        var startError: Error?
        let ok = JJRunCatchingException({
            engine.prepare()
            do {
                try engine.start()
            } catch {
                startError = error
            }
        }, &exception)

        if let exception {
            lastError = "Audio engine failed: \(exception.localizedDescription)"
            log.error("AVAudioEngine exception: \(exception.localizedDescription, privacy: .public)")
            teardownEngine()
            return false
        }
        if let startError {
            lastError = "Audio engine failed: \(startError.localizedDescription)"
            log.error("AVAudioEngine start failed: \(startError.localizedDescription, privacy: .public)")
            teardownEngine()
            return false
        }
        if !ok || !engine.isRunning {
            lastError = "Audio engine did not start. Check the silent switch and volume."
            log.error("AVAudioEngine did not start")
            teardownEngine()
            return false
        }
        return true
    }

    private func teardownEngine() {
        player.stop()
        if let engine {
            if engine.isRunning {
                engine.stop()
            }
            if engine.attachedNodes.contains(player) {
                engine.disconnectNodeOutput(player)
                engine.detach(player)
            }
            if let avAudioUnit, engine.attachedNodes.contains(avAudioUnit) {
                engine.disconnectNodeOutput(avAudioUnit)
                engine.detach(avAudioUnit)
            }
            engine.reset()
        }
        engine = nil
        isPlaying = false
    }

    private func configureSession(for source: Source) {
        let session = AVAudioSession.sharedInstance()
        do {
            switch source {
            case .loop1, .loop2, .loop3:
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            case .microphone:
                try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .mixWithOthers])
            }
            try session.setActive(true)
        } catch {
            lastError = "Audio session failed: \(error.localizedDescription)"
            log.error("Audio session failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func readAudioResource(named name: String) -> AVAudioPCMBuffer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3")
                ?? Bundle.main.url(forResource: name, withExtension: "mp3", subdirectory: "loop")
        else {
            return nil
        }
        do {
            let file = try AVAudioFile(forReading: url)
            let frames = AVAudioFrameCount(file.length)
            guard frames > 0,
                  let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames)
            else { return nil }
            try file.read(into: buffer)
            return buffer
        } catch {
            log.error("Could not read \(name, privacy: .public).mp3: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
