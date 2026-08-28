import WidgetKit
import SwiftUI

@main
struct GoalstarWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayTasksWidget()
        FocusLiveActivity()
    }
}
