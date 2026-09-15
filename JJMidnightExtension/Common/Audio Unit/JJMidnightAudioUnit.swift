import AVFoundation
import AudioToolbox
import CoreAudioKit

public class JJMidnightAudioUnit: AUAudioUnit, @unchecked Sendable {
    var kernel = JJMidnightDSPKernel()
    var processHelper: AUProcessHelper?
    var inputBus = BufferedInputBus()

    private var outputBus: AUAudioUnitBus?
    private var _inputBusses: AUAudioUnitBusArray!
    private var _outputBusses: AUAudioUnitBusArray!
    private var _currentPreset: AUAudioUnitPreset?
    private let presetList: [AUAudioUnitPreset] = FactoryPresets.all.map(\.auPreset)
    private var loadedSnapshot: [String: Float] = [:]

    @objc override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        try super.init(componentDescription: componentDescription, options: options)

        outputBus = try AUAudioUnitBus(format: format)
        outputBus?.maximumChannelCount = 2

        inputBus.initialize(format, 2)

        _inputBusses = AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [inputBus.bus!])
        _outputBusses = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [outputBus!])

        processHelper = AUProcessHelper(&kernel, &inputBus)
    }

    public override var inputBusses: AUAudioUnitBusArray { _inputBusses }
    public override var outputBusses: AUAudioUnitBusArray { _outputBusses }

    public override var channelCapabilities: [NSNumber] {
        [NSNumber(value: 2), NSNumber(value: 2)]
    }

    public override var canProcessInPlace: Bool { true }

    public override var latency: TimeInterval { 0.070 }
    public override var tailTime: TimeInterval { 0.35 }

    public override var maximumFramesToRender: AUAudioFrameCount {
        get { kernel.maximumFramesToRender() }
        set { kernel.setMaximumFramesToRender(newValue) }
    }

    public override var shouldBypassEffect: Bool {
        get { kernel.isBypassed() }
        set { kernel.setBypass(newValue) }
    }

    public override var internalRenderBlock: AUInternalRenderBlock {
        processHelper!.internalRenderBlock()
    }

    public override func allocateRenderResources() throws {
        let inputChannelCount = self.inputBusses[0].format.channelCount
        let outputChannelCount = self.outputBusses[0].format.channelCount

        if outputChannelCount != inputChannelCount {
            setRenderResourcesAllocated(false)
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FailedInitialization), userInfo: nil)
        }

        inputBus.allocateRenderResources(self.maximumFramesToRender)
        kernel.setMusicalContextBlock(self.musicalContextBlock)
        kernel.initialize(Int32(inputChannelCount), Int32(outputChannelCount), outputBus!.format.sampleRate)
        applyLicenseFromStore()
        processHelper?.setChannelCount(inputChannelCount, outputChannelCount)
        try super.allocateRenderResources()
    }

    public override func deallocateRenderResources() {
        kernel.deInitialize()
        super.deallocateRenderResources()
    }

    /// A host that offers several view configurations (e.g. a compact
    /// inline mixer-strip slot alongside a larger "full editor" size) picks
    /// freely among whichever indices we say we support here — once a host
    /// uses this API it can matter more than `preferredContentSize`
    /// (`AudioUnitViewController.idealInitialContentSize`): Loopy Pro
    /// (2026-08-26) showed the exact same cramped panel — only the first
    /// knob row visible — after that preferred-height request was raised
    /// substantially, which is what you'd expect if it's really choosing
    /// from these instead and always landing on a small one because we
    /// blindly said yes to everything. Reject configurations too short for
    /// the panel to be usable, so a host offering a choice is steered
    /// toward a larger one; a height of 0 means "no constraint, you decide"
    /// and is always fine. Never end up with an empty set, though — a host
    /// offering only small configurations still needs *something* to embed.
    public override func supportedViewConfigurations(_ availableViewConfigurations: [AUAudioUnitViewConfiguration]) -> IndexSet {
        let minimumUsableHeight: CGFloat = 320
        let usable: [Int] = availableViewConfigurations.indices.filter { i in
            let height = availableViewConfigurations[i].height
            return height == 0 || height >= minimumUsableHeight
        }
        return usable.isEmpty ? IndexSet(availableViewConfigurations.indices) : IndexSet(usable)
    }

    public override var factoryPresets: [AUAudioUnitPreset]? { presetList }

    public override var supportsUserPresets: Bool { true }

    public override var userPresets: [AUAudioUnitPreset] {
        UserPresetStore.load().map { record in
            let preset = AUAudioUnitPreset()
            preset.number = record.number
            preset.name = record.name
            return preset
        }
    }

    public override func saveUserPreset(_ userPreset: AUAudioUnitPreset) throws {
        guard userPreset.number < 0 else { throw JJMidnightPresetError.persistFailed }
        let snapshot = currentParameterSnapshot()
        var records = UserPresetStore.load()
        if let index = records.firstIndex(where: { $0.number == userPreset.number }) {
            records[index].name = userPreset.name
            records[index].values = snapshot
        } else if let index = records.firstIndex(where: { $0.name.caseInsensitiveCompare(userPreset.name) == .orderedSame }) {
            records[index].values = snapshot
        } else {
            records.append(UserPresetRecord(number: userPreset.number, name: userPreset.name, values: snapshot))
        }
        willChangeValue(forKey: "userPresets")
        try UserPresetStore.save(records)
        didChangeValue(forKey: "userPresets")
    }

    public override func deleteUserPreset(_ userPreset: AUAudioUnitPreset) throws {
        var records = UserPresetStore.load()
        records.removeAll { $0.number == userPreset.number }
        willChangeValue(forKey: "userPresets")
        try UserPresetStore.save(records)
        didChangeValue(forKey: "userPresets")
    }

    public override func presetState(for userPreset: AUAudioUnitPreset) throws -> [String: Any] {
        guard let record = matchingRecord(for: userPreset) else {
            throw JJMidnightPresetError.notFound
        }
        let previous = currentParameterSnapshot()
        applyUserValues(record.values)
        let state = fullState ?? [:]
        applyUserValues(previous)
        return state
    }

    public override var currentPreset: AUAudioUnitPreset? {
        get { _currentPreset }
        set {
            willChangeValue(forKey: "currentPreset")
            defer { didChangeValue(forKey: "currentPreset") }

            guard let preset = newValue else {
                _currentPreset = nil
                return
            }
            if preset.number >= 0 {
                applyFactoryPreset(preset.number)
            } else if let record = matchingRecord(for: preset) {
                applyUserValues(record.values)
            }
            _currentPreset = preset
            loadedSnapshot = currentParameterSnapshot()
            NotificationCenter.default.post(name: .jjMidnightPresetChanged, object: self)
        }
    }

    func saveCurrentStateAsUserPreset(name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw JJMidnightPresetError.emptyName }

        let preset = AUAudioUnitPreset()
        preset.name = trimmed
        if let existing = userPresets.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            preset.number = existing.number
        } else {
            preset.number = nextUserPresetNumber()
        }
        try saveUserPreset(preset)
        currentPreset = preset
    }

    func renameUserPreset(_ preset: AUAudioUnitPreset, to name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw JJMidnightPresetError.emptyName }
        guard preset.number < 0 else { return }

        var records = UserPresetStore.load()
        guard let index = records.firstIndex(where: { $0.number == preset.number }) else {
            throw JJMidnightPresetError.notFound
        }
        records[index].name = trimmed
        willChangeValue(forKey: "userPresets")
        try UserPresetStore.save(records)
        didChangeValue(forKey: "userPresets")

        if _currentPreset?.number == preset.number {
            let updated = AUAudioUnitPreset()
            updated.number = preset.number
            updated.name = trimmed
            willChangeValue(forKey: "currentPreset")
            _currentPreset = updated
            didChangeValue(forKey: "currentPreset")
            NotificationCenter.default.post(name: .jjMidnightPresetChanged, object: self)
        }
    }

    func removeUserPreset(_ preset: AUAudioUnitPreset) throws {
        guard preset.number < 0 else { return }
        let wasCurrent = _currentPreset?.number == preset.number
        try deleteUserPreset(preset)
        if wasCurrent {
            currentPreset = presetList.first
        }
    }

    private func nextUserPresetNumber() -> Int {
        let used = Set(UserPresetStore.load().map(\.number))
        var number = -1
        while used.contains(number) {
            number -= 1
        }
        return number
    }

    private func matchingRecord(for preset: AUAudioUnitPreset) -> UserPresetRecord? {
        let records = UserPresetStore.load()
        if let match = records.first(where: { $0.number == preset.number && $0.name == preset.name }) {
            return match
        }
        if let match = records.first(where: { $0.number == preset.number }) {
            return match
        }
        return records.first(where: { $0.name == preset.name })
    }

    private func currentParameterSnapshot() -> [String: Float] {
        var values: [String: Float] = [:]
        parameterTree?.allParameters.forEach { values[$0.identifier] = $0.value }
        return values
    }

    private func applyUserValues(_ values: [String: Float]) {
        guard let tree = parameterTree else { return }
        for parameter in tree.allParameters {
            if let value = values[parameter.identifier] {
                parameter.value = value
            }
        }
    }

    public func setupParameterTree(_ parameterTree: AUParameterTree) {
        self.parameterTree = parameterTree
        for param in parameterTree.allParameters {
            kernel.setParameter(param.address, param.value)
        }
        setupParameterCallbacks()
        #if DEBUG
        // The kernel's slapback line is sized from this range at prepare
        // time; if the two drift apart, long slap settings clip against the
        // buffer instead of sounding.
        let slapMax = parameterTree.parameter(withAddress: JJMidnightParameterAddress.slapTime.rawValue)?.maxValue ?? 0
        precondition(slapMax >= JJMidnightSlapMaxMs - 0.5, "Slap maxValue is \(slapMax), expected \(JJMidnightSlapMaxMs)")
        #endif
        currentPreset = presetList.first
        loadedSnapshot = currentParameterSnapshot()
        applyLicenseFromStore()
    }

    /// Sync DSP license gate from App Group cache (updated by EntitlementService).
    public func applyLicenseFromStore() {
        kernel.setLicensed(UnlockStore.cachedEffectAllowed)
    }

    public func refreshLicenseFromStore() async {
        await EntitlementService.shared.refresh()
        applyLicenseFromStore()
    }

    func applyFactoryPreset(_ number: Int) {
        guard let preset = FactoryPresets.all.first(where: { $0.number == number }), let tree = parameterTree else { return }
        func set(_ address: JJMidnightParameterAddress, _ value: AUValue) {
            tree.parameter(withAddress: address.rawValue)?.value = value
        }
        set(.compAmount, preset.compAmount)
        set(.compAttack, preset.compAttack)
        set(.compRelease, preset.compRelease)
        set(.driveAmount, preset.driveAmount)
        set(.driveTone, preset.driveTone)
        set(.driveCab, preset.driveCab)
        set(.wobbleRate, preset.wobbleRate)
        set(.wobbleDepth, preset.wobbleDepth)
        set(.wobbleShape, preset.wobbleShape)
        set(.wobbleDivision, preset.wobbleDivision)
        set(.slapTime, preset.slapTime)
        set(.slapMix, preset.slapMix)
        set(.springMix, preset.springMix)
        set(.masterMix, preset.masterMix)
        set(.masterOutput, preset.masterOutput)
        set(.compOn, preset.compOn ? 1 : 0)
        set(.driveOn, preset.driveOn ? 1 : 0)
        set(.wobbleOn, preset.wobbleOn ? 1 : 0)
        set(.wobbleSync, preset.wobbleSync ? 1 : 0)
        set(.spaceOn, preset.spaceOn ? 1 : 0)
    }

    private func setupParameterCallbacks() {
        parameterTree?.implementorValueObserver = { [weak self] param, value in
            self?.kernel.setParameter(param.address, value)
        }

        parameterTree?.implementorValueProvider = { [weak self] param in
            self?.kernel.getParameter(param.address) ?? 0
        }

        parameterTree?.implementorStringFromValueCallback = { param, valuePtr in
            let value = valuePtr?.pointee ?? param.value
            return JJMidnightAudioUnit.format(address: param.address, value: value)
        }
    }

    static func format(address: AUParameterAddress, value: AUValue) -> String {
        switch JJMidnightParameterAddress(rawValue: address) {
        case .compAttack, .compRelease, .slapTime:
            return String(format: "%.0f ms", value)
        case .driveTone:
            return String(format: "%.0f Hz", value)
        case .wobbleRate:
            return String(format: "%.2f Hz", value)
        case .compAmount, .driveAmount, .driveCab,
             .wobbleDepth, .wobbleShape,
             .slapMix, .springMix, .masterMix:
            return String(format: "%.0f %%", value)
        case .masterOutput:
            return String(format: "%+.1f dB", value)
        case .wobbleDivision:
            let names = JJMidnightWobbleDivisions.names
            let index = Swift.min(Swift.max(Int(value.rounded()), 0), names.count - 1)
            return names[index]
        case .compOn, .driveOn, .wobbleOn, .wobbleSync, .spaceOn:
            return value >= 0.5 ? "On" : "Off"
        default:
            return String(format: "%.2f", value)
        }
    }

    static func parse(_ raw: String, address: AUParameterAddress, min: AUValue, max: AUValue) -> AUValue? {
        let cleaned = raw
            .replacingOccurrences(of: ",", with: ".")
            .filter { $0.isNumber || $0 == "." || $0 == "-" || $0 == "+" }
        guard let value = Float(cleaned) else { return nil }
        return Swift.min(max, Swift.max(min, value))
    }

    func takeMeterPeaks() -> (input: Float, output: Float) {
        var input: Float = 0
        var output: Float = 0
        kernel.readPeaks(&input, &output)
        return (input, output)
    }

    /// Left and right output peaks since the last call, then reset. Separate
    /// from `takeMeterPeaks` so the header ladders and the master strip's
    /// stereo bars do not consume each other's readings.
    func takeOutputPeaks() -> (left: Float, right: Float) {
        var left: Float = 0
        var right: Float = 0
        kernel.readOutputPeaks(&left, &right)
        return (left, right)
    }

    /// Current compressor gain reduction in dB, positive when ducking.
    /// Unlike the meter peaks this is a level, not a peak-hold, so reading
    /// it does not reset anything and the UI can poll it as often as it likes.
    func gainReductionDb() -> Float {
        kernel.gainReductionDb()
    }

    func isPresetDirty() -> Bool {
        guard !loadedSnapshot.isEmpty else { return false }
        let now = currentParameterSnapshot()
        for (key, value) in now {
            let reference = loadedSnapshot[key] ?? value
            if abs(reference - value) > 0.35 {
                return true
            }
        }
        return false
    }

    func stepPreset(by delta: Int) {
        let factory = factoryPresets ?? []
        let user = userPresets.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        let all = factory + user
        guard !all.isEmpty else { return }
        let currentNumber = _currentPreset?.number
        let index = all.firstIndex(where: { $0.number == currentNumber }) ?? 0
        let next = (index + delta + all.count * 8) % all.count
        currentPreset = all[next]
    }
}
