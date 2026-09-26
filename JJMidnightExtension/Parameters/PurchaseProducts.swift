import Foundation

enum PurchaseProducts {
    /// One-time unlock ($2.99). Trial is install-date based — no $0 IAP.
    static let unlock = "com.gerov.jjmidnight.unlock"
    /// Same pattern as Gig Songbook stem promo: days from first launch.
    static let trialDurationDays = 7
    static var trialDuration: TimeInterval { TimeInterval(trialDurationDays) * 24 * 60 * 60 }
}

enum AccessState: Equatable, Sendable {
    case trialActive(daysRemaining: Int)
    case trialExpired
    case unlocked

    var isEffectAllowed: Bool {
        switch self {
        case .unlocked, .trialActive: true
        case .trialExpired: false
        }
    }

    var bannerText: String? {
        switch self {
        case .trialActive(let days):
            if days <= 0 { return "Trial ends today — unlock to keep the effect." }
            let unit = days == 1 ? "day" : "days"
            return "\(days) \(unit) left in your free trial."
        case .trialExpired:
            return "Trial ended — unlock jj-midnight to hear the effect again."
        case .unlocked:
            return nil
        }
    }
}
