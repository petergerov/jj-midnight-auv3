import SwiftUI
import CoreAudioKit

struct AudioUnitViewModel {
    var showAudioControls: Bool = false
    var title: String = "-"
    var message: String = "No Audio Unit loaded."
    var viewController: ViewController?
}
