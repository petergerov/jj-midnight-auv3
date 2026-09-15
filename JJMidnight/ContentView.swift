import SwiftUI

struct ContentView: View {
    let hostModel: AudioUnitHostModel
    @Bindable private var entitlement = EntitlementService.shared
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            mainStack
            if !entitlement.isEffectAllowed {
                dryPassNotice
            }
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
        .task {
            await entitlement.loadProducts()
            await entitlement.refresh()
            // Only prompt when the install trial has ended — never on first launch.
            if case .trialExpired = entitlement.accessState {
                showPaywall = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .jjMidnightAccessChanged)) { _ in
            if case .unlocked = entitlement.accessState {
                showPaywall = false
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(entitlement: entitlement, showsCloseWhenAllowed: true) {
                showPaywall = false
            }
        }
    }

    private var mainStack: some View {
        VStack(spacing: 0) {
            header
            editor
            if let playbackError = hostModel.playbackError {
                Text(playbackError)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.85))
            }
            transport
        }
        .task {
            await hostModel.start()
        }
    }

    @ViewBuilder
    private var dryPassNotice: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    showPaywall = true
                } label: {
                    Label("Effect bypassed — tap to unlock", systemImage: "lock.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(GearTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.72))
                        .clipShape(Capsule())
                }
                .padding(8)
            }
            Spacer()
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
                Text(headerStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if hostModel.isPlaying {
                    Label("ON AIR", systemImage: "waveform")
                        .font(.caption.bold())
                        .foregroundStyle(GearTheme.accent)
                }
                if !entitlement.isEffectAllowed {
                    Button("Unlock") { showPaywall = true }
                        .font(.caption.bold())
                        .foregroundStyle(GearTheme.accent)
                }
            }
            if entitlement.accessState.bannerText != nil {
                AccessBanner(state: entitlement.accessState) {
                    showPaywall = true
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(red: 0.08, green: 0.08, blue: 0.09))
    }

    private var headerStatus: String {
        if !entitlement.isEffectAllowed {
            return hostModel.isPlaying ? "Playing dry (unlock required)" : "Standalone player — effect bypassed"
        }
        return hostModel.isPlaying ? "Playing through the effect" : "Standalone player"
    }

    @ViewBuilder
    private var editor: some View {
        if hostModel.isLoading {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading effect…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        } else if let viewController = hostModel.viewModel.viewController {
            AUViewControllerUI(viewController: viewController)
                .background(Color.black)
        } else {
            ContentUnavailableView(
                "Effect did not load",
                systemImage: "waveform",
                description: Text(hostModel.viewModel.message)
            )
        }
    }

    private var transport: some View {
        HStack(spacing: 16) {
            Picker("Source", selection: Binding(
                get: { hostModel.source },
                set: { hostModel.setSource($0) }
            )) {
                ForEach(SimplePlayEngine.Source.allCases) { source in
                    Text(source.rawValue)
                        .accessibilityLabel(source.spokenName)
                        .tag(source)
                }
            }
            .pickerStyle(.segmented)

            Button {
                Task {
                    if hostModel.isPlaying {
                        hostModel.stopPlaying()
                    } else {
                        await hostModel.startPlaying()
                    }
                }
            } label: {
                Label(hostModel.isPlaying ? "Stop" : "Play", systemImage: hostModel.isPlaying ? "stop.fill" : "play.fill")
                    .frame(minWidth: 100)
            }
            .buttonStyle(.borderedProminent)
            .tint(GearTheme.accent)
            .disabled(hostModel.viewModel.viewController == nil || hostModel.isLoading)
        }
        .padding(12)
        .background(Color(red: 0.08, green: 0.08, blue: 0.09))
    }
}
