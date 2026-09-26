import SwiftUI

@main
struct JJMidnightApp: App {
    private let hostModel = AudioUnitHostModel()
    private let entitlement = EntitlementService.shared

    var body: some Scene {
        WindowGroup {
            ContentView(hostModel: hostModel, entitlement: entitlement)
                .preferredColorScheme(.dark)
        }
    }
}
