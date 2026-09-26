import Foundation

/// Cached unlock / trial state shared between the container app and AUv3 extension.
/// Trial start = first launch date (Gig Songbook pattern), stored in `SharedDefaults`.
enum UnlockStore {
    private static let effectAllowedKey = "jjmidnight.effectAllowed.v1"
    private static let accessStateKey = "jjmidnight.accessState.v1"
    private static let installDateKey = "jjmidnight.installDate.v1"

    private static var defaults: UserDefaults { SharedDefaults.primary }

    static var cachedEffectAllowed: Bool {
        for store in [defaults, SharedDefaults.legacy].compactMap({ $0 })
        where store.object(forKey: effectAllowedKey) != nil {
            return store.bool(forKey: effectAllowedKey)
        }
        // Before first refresh: assume trial so audio is not dry on cold start.
        return true
    }

    static var cachedAccessState: AccessState {
        let raw = defaults.string(forKey: accessStateKey)
            ?? SharedDefaults.legacy?.string(forKey: accessStateKey)
        return decode(raw) ?? computeAccessState(hasUnlock: false)
    }

    /// The trial clock's start. A date only an earlier build's second copy
    /// holds is carried forward, so moving to one store never restarts the
    /// trial.
    static var installDate: Date? {
        if let date = defaults.object(forKey: installDateKey) as? Date { return date }
        guard let date = SharedDefaults.legacy?.object(forKey: installDateKey) as? Date else { return nil }
        defaults.set(date, forKey: installDateKey)
        return date
    }

    /// Records first launch if missing (both app and extension call this).
    @discardableResult
    static func ensureInstallDate() -> Date {
        if let existing = installDate { return existing }
        let now = Date()
        defaults.set(now, forKey: installDateKey)
        return now
    }

    static func computeAccessState(hasUnlock: Bool) -> AccessState {
        if hasUnlock { return .unlocked }
        let start = ensureInstallDate()
        let elapsed = Date().timeIntervalSince(start)
        if elapsed < PurchaseProducts.trialDuration {
            let remaining = PurchaseProducts.trialDuration - elapsed
            let days = max(0, Int(ceil(remaining / (24 * 60 * 60))))
            return .trialActive(daysRemaining: days)
        }
        return .trialExpired
    }

    static func write(accessState: AccessState) {
        defaults.set(accessState.isEffectAllowed, forKey: effectAllowedKey)
        defaults.set(encode(accessState), forKey: accessStateKey)
    }

    private static func encode(_ state: AccessState) -> String {
        switch state {
        case .trialExpired: "expired"
        case .unlocked: "unlock"
        case .trialActive(let days): "trial:\(days)"
        }
    }

    private static func decode(_ raw: String?) -> AccessState? {
        guard let raw else { return nil }
        // Legacy $0-IAP state — treat as expired so user sees unlock (or still in trial via install date).
        if raw == "none" { return nil }
        if raw == "expired" { return .trialExpired }
        if raw == "unlock" { return .unlocked }
        if raw.hasPrefix("trial:"), let days = Int(raw.dropFirst(6)) {
            return .trialActive(daysRemaining: days)
        }
        return nil
    }
}
