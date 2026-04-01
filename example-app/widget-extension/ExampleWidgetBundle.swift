import WidgetKit
import CapgoWidgetKitPlugin

@main
struct ExampleWidgetBundle: WidgetBundle {
    var body: some Widget {
        CapgoWorkoutLiveActivityWidget()
    }
}
