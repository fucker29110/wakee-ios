import WidgetKit
import SwiftUI

@main
struct WakeeWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WakeeAlarmLiveActivity()
        WakeeReceiverAlarmLiveActivity()
    }
}
