import Combine
import CoreAudioKit
import os
import SwiftUI
import UIKit

private let log = Logger(subsystem: "com.gerov.jjmidnight.AUv3", category: "AudioUnitViewController")

@objc(AudioUnitViewController)
@MainActor
public class AudioUnitViewController: AUViewController, AUAudioUnitFactory {
    var audioUnit: AUAudioUnit?
    var hostingController: HostingController<JJMidnightMainView>?
    private var observation: NSKeyValueObservation?

    public override func viewDidLoad() {
        super.viewDidLoad()
        // Fallback for the sliver of time before an audio unit is attached,
        // in case a host reads preferredContentSize that early. In practice
        // createAudioUnit runs first and configureSwiftUIView below replaces
        // this with a value computed from the real content.
        preferredContentSize = CGSize(width: 700, height: 670)
        guard let audioUnit else { return }
        configureSwiftUIView(audioUnit: audioUnit)
    }

    /// Must not `DispatchQueue.main.sync` when already on the main thread — that deadlocks
    /// the extension process and the host reports "Audio Unit failed to load".
    nonisolated public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        let unit = try JJMidnightAudioUnit(componentDescription: componentDescription, options: [])
        unit.setupParameterTree(JJMidnightParameterSpecs.createAUParameterTree())

        let attach = {
            MainActor.assumeIsolated {
                self.attach(unit)
            }
        }
        if Thread.isMainThread {
            attach()
        } else {
            DispatchQueue.main.sync(execute: attach)
        }
        return unit
    }

    private func attach(_ unit: JJMidnightAudioUnit) {
        audioUnit = unit
        observation = unit.observe(\.allParameterValues, options: [.new]) { _, _ in
            guard let tree = unit.parameterTree else { return }
            for param in tree.allParameters { param.value = param.value }
        }
        if isViewLoaded {
            configureSwiftUIView(audioUnit: unit)
        }
    }

    private func configureSwiftUIView(audioUnit: AUAudioUnit) {
        if let host = hostingController {
            host.removeFromParent()
            host.view.removeFromSuperview()
        }

        guard let observableParameterTree = audioUnit.observableParameterTree else { return }
        let model = MainPanelViewModel(audioUnit: audioUnit as? JJMidnightAudioUnit,
                                       entitlement: EntitlementService.shared)
        let content = JJMidnightMainView(parameterTree: observableParameterTree, model: model)
        preferredContentSize = idealInitialContentSize(for: content)
        let host = HostingController(rootView: content)
        self.addChild(host)
        host.view.frame = self.view.bounds
        self.view.addSubview(host.view)
        hostingController = host

        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: self.view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
        self.view.bringSubviewToFront(host.view)
    }

    /// A host (Logic, GarageBand, Loopy Pro…) reads `preferredContentSize`
    /// before it has given us any frame to lay out in, so we can't just ask
    /// our real view how big it wants to be the normal SwiftUI way. Instead,
    /// host the panel's actual content (`JJMidnightMainView.panelContent`,
    /// which reports its natural height for a given width rather than
    /// always filling like `body` does) off-screen and measure it — this
    /// was previously a single hand-tuned constant shared by every device,
    /// which is what caused clipping: an iPhone's width falls under
    /// `wideThreshold` and stacks the three sections, needing far more
    /// height than the wide iPad layout, but got the same request anyway.
    private func idealInitialContentSize(for content: JJMidnightMainView) -> CGSize {
        let screen = UIScreen.main.bounds.size
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        // Wide enough for the three columns side by side only on a
        // regular-width device — narrower devices fall back to the taller
        // stacked layout (see wideThreshold in JJMidnightMainView).
        let width: CGFloat = isPad ? 900 : max(320, min(screen.width, screen.height) - 20)

        let measuringHost = HostingController(rootView: content.panelContent(width: width))
        let fitting = measuringHost.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
        // Generous slack, not just a rounding cushion: real hosts (Loopy Pro
        // confirmed 2026-08-26 — content scrolled but was clearly given far
        // less than requested; GarageBand showed the same pattern earlier)
        // eat into the requested height for their own chrome around the
        // panel rather than handing over the exact figure asked for. Asking
        // for more than the bare content height doesn't cost anything even
        // in a host that *does* honor it exactly — panelContent centres
        // itself in any extra space instead of stretching or leaving a
        // visible gap (see the Spacer(minLength: 0) pair around it in
        // JJMidnightMainView.body).
        let height = min(fitting.height + 120, isPad ? 900 : 1000)
        return CGSize(width: width, height: height)
    }
}
