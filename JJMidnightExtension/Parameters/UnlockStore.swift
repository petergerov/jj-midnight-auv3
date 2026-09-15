import Foundation

/// Cached unlock / trial state shared between the container app and AUv3 extension.
/// Trial start = first launch date (Gig Songbook pattern), stored in App Group + standard defaults.
enum UnlockStore {
    private static let effectAllowedKey = "jjmidnight.effectAllowed.v1"
    private static let accessStateKey = "jjmidnight.accessState.v1"
    private static let installDateKey = "jjmidnight.installDate.v1"

    static var cachedEffectAllowed: Bool {
        if let suite = groupDefaults, suite.object(forKey: effectAllowedKey) != nil {
            return suite.bool(forKey: effectAllowedKey)
        }
        if UserDefaults.standard.object(forKey: effectAllowedKey) != nil {
            return UserDefaults.standard.bool(forKey: effectAllowedKey)
        }
        // Before first refresh: assume trial so audio is not dry on cold start.
        return true
    }

    static var cachedAccessState: AccessState {
        let raw = groupDefaults?.string(forKey: accessStateKey)
            ?? UserDefaults.standard.string(forKey: accessStateKey)
        return decode(raw) ?? computeAccessState(hasUnlock: false)
    }

    static var installDate: Date? {
        if let date = groupDefaults?.object(forKey: installDateKey) as? Date { return date }
        return UserDefaults.standard.object(forKey: installDateKey) as? Date
    }

    /// Records first launch if missing (both app and extension call this).
    @discardableResult
    static func ensureInstallDate() -> Date {
        if let existing = installDate { return existing }
        let now = Date()
        writeInstallDate(now)
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
        let allowed = accessState.isEffectAllowed
        let encoded = encode(accessState)
        if let suite = groupDefaults {
            suite.set(allowed, forKey: effectAllowedKey)
            suite.set(encoded, forKey: accessStateKey)
        }
        UserDefaults.standard.set(allowed, forKey: effectAllowedKey)
        UserDefaults.standard.set(encoded, forKey: accessStateKey)
    }

    private static func writeInstallDate(_ date: Date) {
        if let suite = groupDefaults {
            suite.set(date, forKey: installDateKey)
        }
        UserDefaults.standard.set(date, forKey: installDateKey)
    }

    private static var groupDefaults: UserDefaults? {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: UserPresetStore.appGroupID) != nil else {
            return nil
        }
        return UserDefaults(suiteName: UserPresetStore.appGroupID)
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
