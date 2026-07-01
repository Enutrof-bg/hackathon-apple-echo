import WidgetKit

#if WIDGET_EXTENSION
@main
struct EchoPriorityWidgetBundle: WidgetBundle {
    var body: some Widget {
        EchoOfTheDayWidget()
        EchoDiscoverNextWidget()
        EchoQuickCaptureWidget()
    }
}
#endif
