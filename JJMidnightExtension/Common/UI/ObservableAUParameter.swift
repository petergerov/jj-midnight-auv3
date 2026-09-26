import SwiftUI
import AudioToolbox

/// Observable versions of every parameter in an AUParameterTree, looked up by
/// address.
///
/// Flat rather than mirroring the tree's groups: the panel addresses each
/// parameter directly (`parameterTree[.compOn]`), so a misspelt name is a
/// compile error instead of the runtime trap a string lookup through the
/// groups would be. The groups still exist in the AUParameterTree for hosts.
@MainActor
final class ObservableAUParameterGroup {

    private let parameters: [AUParameterAddress: ObservableAUParameter]

    init(_ parameterTree: AUParameterGroup) {
        parameters = Dictionary(
            uniqueKeysWithValues: parameterTree.allParameters.map { ($0.address, ObservableAUParameter($0)) }
        )
    }

    subscript(_ address: JJMidnightParameterAddress) -> ObservableAUParameter {
        guard let parameter = parameters[address.rawValue] else {
            // Only reachable if Parameters.swift stops declaring an address
            // the panel draws — a build that got this far is already broken.
            preconditionFailure("No parameter for address \(address.rawValue); is it missing from JJMidnightParameterSpecs?")
        }
        return parameter
    }
}

/// An Observable version of AUParameter
///
/// ObservableAUParameter is intended to be used directly in SwiftUI views as an ObservedObject,
/// allowing us to expose a binding to the parameter's value, as well as associated parameter data,
/// like the minimum, maximum, and default values for the parameter.
///
/// The ObservableAUParameter can also manage automation event types by calling
/// `onEditingChanged()` whenever a UI element will change its editing state.
@MainActor
@Observable
final class ObservableAUParameter {

    private weak var parameter: AUParameter?
    private var observer: ParameterObserverRegistration?
    private var editingState: EditingState = .inactive

    let min: AUValue
    let max: AUValue
    let displayName: String
    let defaultValue: AUValue
    let unit: AudioUnitParameterUnit
    let address: AUParameterAddress

    init(_ parameter: AUParameter) {
        self.parameter = parameter
        self.value = parameter.value
        self.displayName = parameter.displayName
        let range = ParameterDefaults.ranges[parameter.address]
        self.min = range?.min ?? parameter.minValue
        self.max = range?.max ?? parameter.maxValue
        self.defaultValue = ParameterDefaults.values[parameter.address] ?? parameter.value
        self.unit = parameter.unit
        self.address = parameter.address

        /// Use the parameter.token(byAddingParameterObserver:) function to monitor for parameter
        /// changes from the host. The only role of this callback is to update the UI if the value is changed by the host.
        ///
        /// `self` is captured weakly: the parameter tree retains this block for as long as the
        /// observer is registered, so a strong capture would keep every rebuilt panel's
        /// parameters alive — and observing — for the life of the audio unit.
        let token = parameter.token { @Sendable [weak self] (_ address: AUParameterAddress, _ auValue: AUValue) in

            DispatchQueue.main.async {
                guard let self, address == self.parameter?.address else { return }

                // Don't update the UI if the user is currently interacting
                guard self.editingState == .inactive else { return }

                self.editingState = .hostUpdate
                self.value = auValue
                self.editingState = .inactive
            }
        }
        self.observer = ParameterObserverRegistration(parameter: parameter, token: token)
    }

    var value: AUValue {
        didSet {
            /// If the editing state is .hostUpdate, don't propagate this back to the host
            guard editingState != .hostUpdate, let observer else { return }

            let automationEventType = resolveEventType()
            parameter?.setValue(
                value,
                originator: observer.token,
                atHostTime: 0,
                eventType: automationEventType
            )
        }
    }

    var boolValue: Bool {
       get {
		   value >= 0.5
        }
        set {
            value = newValue ? 1.0 : 0.0
        }
    }

    /// A callback for UI elements to notify the Parameter when UI editing state changes
    ///
    /// This is the core mechanism for ensuring correct automation behavior. With native SwiftUI elements like `Slider`,
    /// this method should be passed directly into the `onEditingChanged:` argument.
    ///
    /// As long as the UI Element correctly sets the editing state, then the ObservableAUParameter's calls to
    /// AUParameter.setValue will contain the correct automation event type.
    ///
    /// `onEditingChanged` should be called with `true` before the first value is sent, so that it can be sent with a
    /// `.touch` event. It's expected that `onEditingChanged` is called with a value of `false` to mark the end
    /// of interaction *after* the last value has been sent, since this is how SwiftUI's `Slider` and `Stepper` views behave.
    func onEditingChanged(_ editing: Bool) {
        if editing {
            editingState = .began
        } else {
            editingState = .ended

            // We set the value here again to prompt its `didSet` implementation, so that we can send the appropriate `.release` event.
            value = value
        }
    }

    private func resolveEventType() -> AUParameterAutomationEventType {
        let eventType: AUParameterAutomationEventType
        switch editingState {
        case .began:
            eventType = .touch
            editingState = .active
        case .ended:
            eventType = .release
            editingState = .inactive
        default:
            eventType = .value
        }
        return eventType
    }

    private enum EditingState {
        case inactive
        case began
        case active
        case ended
        case hostUpdate
    }
}

/// Owns one parameter observer and removes it when released.
///
/// A separate object rather than a `deinit` on ObservableAUParameter because that class is
/// main-actor isolated and its deinit is not: this one holds only the two values the removal
/// needs, so it can run from wherever the last reference goes away.
private final class ParameterObserverRegistration: @unchecked Sendable {
    let token: AUParameterObserverToken
    private weak var parameter: AUParameter?

    init(parameter: AUParameter, token: AUParameterObserverToken) {
        self.parameter = parameter
        self.token = token
    }

    deinit {
        parameter?.removeParameterObserver(token)
    }
}

extension AUAudioUnit {
    // Can we subclass the Parameter tree to set that on the AUAudioUnit?

    @MainActor var observableParameterTree: ObservableAUParameterGroup? {
        guard let paramTree = self.parameterTree else { return nil }
        return ObservableAUParameterGroup(paramTree)
    }
}
