import StoreKit
import SwiftUI

struct PaywallView: View {
    @Bindable var entitlement: EntitlementService
    var showsCloseWhenAllowed = false
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(GearTheme.accent)
                .padding(.bottom, 4)

            Text("jj-midnight")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .italic()
                .foregroundStyle(.white)

            Text(headline)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            VStack(alignment: .leading, spacing: 10) {
                bullet("7 days free from first launch — no signup")
                bullet("Then unlock once — no subscription")
                bullet("Works in GarageBand, Logic for iPad, and AUM")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)

            if let message = entitlement.lastError {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 12) {
                Button {
                    Task { await entitlement.purchaseUnlock() }
                } label: {
                    Text("Unlock forever — \(unlockLabel)")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(GearTheme.accent)
                .disabled(entitlement.isPurchasing || entitlement.unlockProduct == nil)

                Button("Restore purchases") {
                    Task { await entitlement.restorePurchases() }
                }
                .font(.footnote)
                .disabled(entitlement.isPurchasing)
            }
            .padding(.horizontal, 24)

            Text("After the trial, audio passes through dry until you unlock. The editor stays available.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Spacer(minLength: 0)

            if showsCloseWhenAllowed {
                if case .unlocked = entitlement.accessState {
                    Button("Continue") { onDismiss?() }
                        .font(.footnote)
                        .padding(.bottom, 8)
                } else {
                    Button("Not now") { onDismiss?() }
                        .font(.footnote)
                        .padding(.bottom, 8)
                }
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .task {
            await entitlement.loadProducts()
            await entitlement.refresh()
        }
        .onChange(of: entitlement.accessState) { _, state in
            if case .unlocked = state, showsCloseWhenAllowed {
                onDismiss?()
            }
        }
    }

    private var headline: String {
        switch entitlement.accessState {
        case .trialExpired:
            return "Your free trial has ended. Unlock to keep this electric guitar effect."
        case .trialActive:
            return "Enjoying the trial? Unlock once to keep this electric guitar effect forever."
        case .unlocked:
            return "You’re unlocked. Thanks for supporting jj-midnight."
        }
    }

    private var unlockLabel: String {
        entitlement.unlockProduct?.displayPrice ?? "$2.99"
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
        }
    }
}

/// Compact banner for the plugin header when trial is active or expired.
struct AccessBanner: View {
    let state: AccessState
    var onUnlock: () -> Void

    var body: some View {
        if let text = state.bannerText {
            HStack(spacing: 8) {
                Text(text)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(GearTheme.ledText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 4)
                if case .unlocked = state {
                    EmptyView()
                } else {
                    Button("Unlock", action: onUnlock)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(GearTheme.accent)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(LedWindow(cornerRadius: 3))
        }
    }
}
